# プッシュサブスクリプション セットアップガイド

## 概要

プッシュサブスクリプションは、Publisher（配信元）から Subscriber（配信先）へデータを"押し出す"方式です。
Distribution Agent が Publisher 側で動作し、Subscriber が常時稼働している環境に適しています。

## 特徴

- **Distribution Agent の場所**: Publisher 側
- **制御**: 中央集中型（Publisher が配信を制御）
- **適用シーン**: Subscriber が常時稼働している環境
- **ネットワーク要件**: Publisher から Subscriber への接続が必要

## セットアップ手順

### 1. コンテナの起動

```powershell
docker-compose up -d
```

コンテナが healthy になるまで待機します（約30秒）。

```powershell
docker-compose ps
```

### 2. Subscriber のセットアップ

Subscriber 側でデータベースとテーブルスキーマを作成します。

```powershell
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -i /var/opt/mssql/subscriber-setup-push.sql -C
```

**期待される出力**:
```
ReplicationDB created successfully on Subscriber.
Products table created successfully on Subscriber.
Subscriber setup completed!
```

### 3. Publisher のセットアップ

Publisher 側で配布データベース、パブリケーション、およびプッシュサブスクリプションを作成します。

```powershell
docker exec -it sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -i /var/opt/mssql/publisher-setup-push.sql -C
```

**期待される出力**:
```
ReplicationDB created successfully.
Products table created successfully.
Sample data inserted into Products table.
Distribution database configured successfully.
Publication "ProductPublication" created successfully.
Subscription to Subscriber added successfully.
Publisher setup completed!
```

### 4. スナップショットの開始

初回同期のためにスナップショットエージェントを実行します。

```powershell
docker exec -it sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d ReplicationDB -Q "EXEC sp_startpublication_snapshot @publication = N'ProductPublication';" -C
```

**期待される出力**:
```
Command completed successfully.
```

スナップショットが完了するまで数秒待ちます。

## 動作確認

### 初期データの確認

Subscriber 側のデータを確認します（5件のサンプルデータが同期されているはず）。

```powershell
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d ReplicationDB -Q "SELECT * FROM Products;" -C
```

### リアルタイムレプリケーションのテスト

Publisher 側で新しいデータを挿入します。

```powershell
docker exec -it sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d ReplicationDB -Q "INSERT INTO Products (ProductName, Price) VALUES ('Webcam', 59.99);" -C
```

数秒後、Subscriber 側で確認します。

```powershell
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d ReplicationDB -Q "SELECT * FROM Products WHERE ProductName = 'Webcam';" -C
```

新しいレコードが表示されればレプリケーション成功です。

## トラブルシューティング

### レプリケーションエージェントの状態確認

```powershell
docker exec -it sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d distribution -Q "SELECT name, description, start_execution_date, stop_execution_date FROM MSdistribution_agents;" -C
```

### エラーログの確認

```powershell
docker exec -it sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d distribution -Q "SELECT TOP 10 time, error_id, error_text FROM MSdistribution_history ORDER BY time DESC;" -C
```

## クリーンアップ

環境を初期化する場合:

```powershell
docker-compose down -v
```

これによりコンテナ、ネットワーク、およびボリュームがすべて削除されます。
