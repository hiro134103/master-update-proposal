# プッシュサブスクリプション検証結果

## 検証日時
2025年12月7日

## 検証環境
- **Publisher**: SQL Server 2019 (Docker コンテナ)
  - ホスト: sqlpublisher
  - ポート: 1433
- **Subscriber**: SQL Server 2019 (Docker コンテナ)
  - ホスト: sqlsubscriber
  - ポート: 1434
- **レプリケーションタイプ**: トランザクションレプリケーション（プッシュサブスクリプション）
- **パブリケーション**: ProductPublication
- **対象テーブル**: Products

## 検証手順

### 1. 環境構築
```bash
# コンテナとボリュームを完全にクリーンアップ
docker-compose down -v

# 環境を起動
docker-compose up -d

# SQL Server が完全に起動するまで待機（約25秒）
# 両コンテナが "healthy" 状態になることを確認
docker ps
```

### 2. セットアップ実行
```bash
# Subscriber のセットアップ
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -i /var/opt/mssql/push-subscriber-setup.sql -C

# Publisher のセットアップ
docker exec -it sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -i /var/opt/mssql/push-publisher-setup.sql -C

# スナップショットエージェントを手動で開始
docker exec sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d ReplicationDB -Q "EXEC sp_startpublication_snapshot @publication = N'ProductPublication';" -C
```

### 3. 初期同期の確認
```bash
# スナップショット生成とレプリケーション完了まで待機（約20秒）
timeout /t 20

# Subscriber のデータを確認
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d ReplicationDB -Q "SELECT * FROM Products;" -C
```

## 検証結果

### ✅ 初期同期（スナップショットレプリケーション）

**Publisher のデータ（5行）:**
```
ProductID   ProductName    Price
----------- -------------- ------------
1           Laptop         999.99
2           Mouse          25.50
3           Keyboard       75.00
4           Monitor        299.99
5           Headphones     89.99
```

**Subscriber への同期結果:**
- ✅ **成功**: 5行すべてが正常にレプリケーションされた
- タイムスタンプ: 2025-12-07 13:17:44.613

### ✅ リアルタイムレプリケーション

**テスト内容:**
```sql
-- Publisher に2行のデータを挿入
INSERT INTO Products (ProductName, Price) VALUES ('Webcam', 149.99), ('USB Cable', 9.99);
```

**Subscriber への反映結果（約10秒後）:**
```
ProductID   ProductName    Price        LastModified
----------- -------------- ------------ -----------------------
1           Laptop         999.99       2025-12-07 13:17:44.613
2           Mouse          25.50        2025-12-07 13:17:44.613
3           Keyboard       75.00        2025-12-07 13:17:44.613
4           Monitor        299.99       2025-12-07 13:17:44.613
5           Headphones     89.99        2025-12-07 13:17:44.613
6           Webcam         149.99       2025-12-07 13:19:47.983  ← 新規追加
7           USB Cable      9.99         2025-12-07 13:19:47.983  ← 新規追加
```

- ✅ **成功**: 新規挿入した2行が自動的に Subscriber に反映された
- レプリケーション遅延: 約10秒以内

## 確認されたレプリケーションの動作

1. **スナップショットレプリケーション**: ✅ 正常動作
   - 初期データ（5行）が Subscriber に正常に転送された
   
2. **トランザクションレプリケーション**: ✅ 正常動作
   - Publisher での INSERT 操作が自動的に Subscriber に反映された
   - Log Reader Agent が Publisher のトランザクションログを読み取り
   - Distribution Agent が変更を Subscriber に配信

3. **Distribution Agent**: ✅ 正常動作（Publisher 側）
   - バックグラウンドで継続的に実行
   - 設定: 5秒間隔でポーリング（`@frequency_subday_interval = 5`）

## エージェントの動作確認

### Log Reader Agent
- ジョブ名: `SQLPUBLISHER-ReplicationDB-1`
- ステータス: ✅ 起動中
- 役割: Publisher のトランザクションログを distribution データベースに転送

### Snapshot Agent
- ジョブ名: `SQLPUBLISHER-ReplicationDB-ProductPublication-1`
- ステータス: ✅ 正常実行（手動トリガー）
- 役割: 初期スナップショットを生成

### Distribution Agent
- ジョブ名: `sqlpublisher-ReplicationDB-ProductPublication-SQLSUBSCRIBER-1`
- ステータス: ✅ 起動中
- 役割: distribution データベースから Subscriber へ変更を配信
- 履歴確認結果:
  ```
  time                    comments
  ----------------------- ----------------------------------------
  2025-12-07 13:14:01.280 2 transaction(s) with 2 command(s) were delivered.
  2025-12-07 13:14:01.030 Initializing
  2025-12-07 13:13:57.183 Starting agent.
  ```

## 注意事項

1. **スナップショットの手動実行が必要**
   - 現在の設定では、セットアップ後にスナップショットエージェントを手動で実行する必要がある
   - 自動実行にする場合は、publisher-setup.sql の最後にスナップショット実行コマンドを追加可能

2. **証明書の警告**
   - `-C` オプションで証明書検証をスキップしているため、本番環境では適切な証明書設定が必要

3. **SQL Server Agent の依存**
   - レプリケーションは SQL Server Agent に依存しているため、Agent が停止するとレプリケーションも停止する
   - Docker Compose では `MSSQL_AGENT_ENABLED=true` で有効化済み

## プッシュサブスクリプションの利点

- ✅ **中央集中管理**: Publisher が一括して配信を制御
- ✅ **即時配信**: Distribution Agent が Publisher 側で常時動作
- ✅ **シンプルな設定**: Subscriber 側の設定が最小限
- ✅ **監視が容易**: Publisher 側で全サブスクリプションの状態を確認可能

## 結論

✅ **SQL Server のトランザクションレプリケーション（プッシュサブスクリプション）が Docker 環境で正常に動作することを確認**

- 初期同期（スナップショット）: 正常（5行）
- リアルタイムレプリケーション（トランザクション）: 正常（2行、10秒以内）
- すべてのレプリケーションエージェント: 正常動作

この構成は、Subscriber が常時稼働している環境（例：中央サーバーから各部門サーバーへのデータ配信）に適しています。
