# プルサブスクリプション セットアップガイド

## 概要

プルサブスクリプションは、Subscriber（配信先）が Publisher（配信元）からデータを"引き出す"方式です。
Distribution Agent が Subscriber 側で動作し、Subscriber が間欠的に稼働する環境に適しています。

## 特徴

- **Distribution Agent の場所**: Subscriber 側
- **制御**: 分散型（各 Subscriber が取得を制御）
- **適用シーン**: Subscriber が間欠的に稼働する環境（各部門サーバーなど）
- **ネットワーク要件**: Subscriber から Publisher への接続が必要
- **メリット**: Subscriber がオフラインでも Publisher に影響なし

## セットアップ手順

### 前提条件: UNC フォルダ構造の作成

プルサブスクリプションでは、Subscriber がスナップショットファイルにアクセスする必要があります。
SQL Server on Linux は自動的に `\unc\` サブフォルダを追加するため、事前に作成する必要があります。

```powershell
docker exec -u root sqlpublisher bash -c "mkdir -p '/var/opt/mssql/ReplData/unc/SQLPUBLISHER_REPLICATIONDB_PRODUCTPUBLICATION' && chmod -R 777 /var/opt/mssql/ReplData"
```

**期待される出力**: なし（エラーが出なければ成功）

### 1. コンテナの起動

```powershell
docker-compose up -d
```

コンテナが healthy になるまで待機します（約30秒）。

```powershell
docker-compose ps
```

### 2. Publisher のセットアップ

Publisher 側で配布データベースとパブリケーションを作成します。

```powershell
docker exec -it sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -i /var/opt/mssql/pull-publisher-setup.sql -C
```

**期待される出力**:
```
ReplicationDB created successfully.
Products table created successfully.
Sample data inserted into Products table.
Distribution database configured successfully.
Publication "ProductPublication" created successfully.
Publisher setup completed!
Note: Pull subscriptions will be created from each Subscriber.
```

### 3. サブスクリプションの登録（Publisher 側）

スナップショット生成前に、Publisher 側でサブスクリプションを登録する必要があります。

```powershell
docker exec sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d ReplicationDB -Q "EXEC sp_addsubscription @publication = N'ProductPublication', @subscriber = N'sqlsubscriber', @destination_db = N'ReplicationDB', @subscription_type = N'pull', @sync_type = N'automatic', @article = N'all', @update_mode = N'read only', @subscriber_type = 0;" -C
```

**期待される出力**:
```
Command(s) completed successfully.
```

### 4. スナップショットの作成

初回同期のためにスナップショットを作成します。

```powershell
docker exec sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d ReplicationDB -Q "EXEC sp_startpublication_snapshot @publication = N'ProductPublication';" -C
```

**期待される出力**:
```
Command(s) completed successfully.
```

スナップショットが完了するまで約10秒待ちます。

### 5. スナップショットファイルの確認（オプション）

```powershell
docker exec sqlpublisher find /var/opt/mssql/ReplData -type f
```

**期待される出力例**:
```
/var/opt/mssql/ReplData/unc/SQLPUBLISHER_REPLICATIONDB_PRODUCTPUBLICATION/20251207142620/Products_2.pre
/var/opt/mssql/ReplData/unc/SQLPUBLISHER_REPLICATIONDB_PRODUCTPUBLICATION/20251207142620/Products_2.idx
/var/opt/mssql/ReplData/unc/SQLPUBLISHER_REPLICATIONDB_PRODUCTPUBLICATION/20251207142620/Products_2.bcp
/var/opt/mssql/ReplData/unc/SQLPUBLISHER_REPLICATIONDB_PRODUCTPUBLICATION/20251207142620/Products_2.sch
```

### 6. Subscriber のセットアップ

Subscriber 側でデータベース、テーブル、およびプルサブスクリプションを作成します。

```powershell
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -i /var/opt/mssql/pull-subscriber-setup.sql -C
```

**期待される出力**:
```
ReplicationDB created successfully on Subscriber.
Products table created successfully on Subscriber.
Pull subscription created successfully on Subscriber.
Distribution Agent job created on Subscriber.
Subscriber setup completed!
Distribution Agent will automatically synchronize data from Publisher.
```

## 動作確認

### 初期データの確認

Subscriber 側のデータを確認します（5件のサンプルデータが同期されているはず）。

```powershell
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d ReplicationDB -Q "SELECT * FROM Products;" -C
```

**期待される出力**:
```
ProductID   ProductName    Price
----------- -------------- ------------
1           Laptop         999.99
2           Mouse          25.50
3           Keyboard       75.00
4           Monitor        299.99
5           Headphones     89.99

(5 rows affected)
```

### リアルタイムレプリケーションのテスト

Publisher 側で新しいデータを挿入します。

```powershell
docker exec sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d ReplicationDB -Q "INSERT INTO Products (ProductName, Price) VALUES ('Tablet', 399.99), ('Smartwatch', 249.99);" -C
```

約15秒待機してから、Subscriber 側で確認します。

```powershell
Start-Sleep -Seconds 15; docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d ReplicationDB -Q "SELECT * FROM Products WHERE ProductID > 5;" -C
```

**期待される出力**:
```
ProductID   ProductName    Price
----------- -------------- ------------
6           Tablet         399.99
7           Smartwatch     249.99

(2 rows affected)
```

新しいレコードが表示されればレプリケーション成功です。Distribution Agent が Subscriber 側で自動的にトランザクションを取得して適用しています。

## プルサブスクリプションの重要な技術ポイント

### 1. 共有ボリューム
`docker-compose.yml` で両コンテナに `snapshot_share` ボリュームをマウントしています:
```yaml
volumes:
  - snapshot_share:/var/opt/mssql/ReplData
```

### 2. UNC パス対応
SQL Server on Linux は自動的に `\unc\` サブフォルダを追加するため、事前に作成が必要です:
```bash
/var/opt/mssql/ReplData/unc/SQLPUBLISHER_REPLICATIONDB_PRODUCTPUBLICATION/
```

### 3. SQL Server 認証
Docker Linux 環境では Windows 認証が使用できないため、SQL Server 認証を使用します:
```sql
@distributor_security_mode = 0,
@distributor_login = N'sa',
@distributor_password = N'YourStrong@Passw0rd'
```

### 4. Distribution Agent の場所
プルサブスクリプションでは、Distribution Agent は **Subscriber 側**で動作します。

## トラブルシューティング

### エージェントジョブの確認

Subscriber 側で Distribution Agent ジョブを確認:

```powershell
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -Q "SELECT job_id, name, enabled, date_modified FROM msdb.dbo.sysjobs WHERE name LIKE '%ProductPublication%';" -C
```

### サブスクリプションの状態確認

```powershell
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d ReplicationDB -Q "SELECT * FROM dbo.MSreplication_subscriptions;" -C
```

### Publisher への接続確認

```powershell
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S sqlpublisher -U sa -P "YourStrong@Passw0rd" -Q "SELECT @@SERVERNAME;" -C
```

### スナップショットフォルダの確認

Publisher 側でスナップショットファイルが正しく生成されているか確認:

```powershell
docker exec sqlpublisher find /var/opt/mssql/ReplData -type f
```

期待される出力例:
```
/var/opt/mssql/ReplData/unc/SQLPUBLISHER_REPLICATIONDB_PRODUCTPUBLICATION/20251207142620/Products_2.pre
/var/opt/mssql/ReplData/unc/SQLPUBLISHER_REPLICATIONDB_PRODUCTPUBLICATION/20251207142620/Products_2.idx
/var/opt/mssql/ReplData/unc/SQLPUBLISHER_REPLICATIONDB_PRODUCTPUBLICATION/20251207142620/Products_2.bcp
/var/opt/mssql/ReplData/unc/SQLPUBLISHER_REPLICATIONDB_PRODUCTPUBLICATION/20251207142620/Products_2.sch
```

### Distribution Agent のエラー確認

```powershell
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -Q "SELECT TOP 10 time, error_id, comments FROM distribution.dbo.MSdistribution_history ORDER BY time DESC;" -C
```

## 注意事項

1. **共有ボリュームが必須**
   - プルサブスクリプションでは、Subscriber がスナップショットファイルにアクセスする必要があります
   - `docker-compose.yml` で `snapshot_share` ボリュームを両コンテナにマウント済み

2. **UNC フォルダの事前作成**
   - セットアップ前に必ず UNC フォルダ構造を作成してください
   - SQL Server on Linux は自動的に `\unc\` を追加するため、手動で作成が必要です

3. **SQL Server 認証**
   - Docker Linux 環境では Windows 認証が使用できません
   - SQL Server 認証（sa ユーザー）を使用してください

4. **サブスクリプション登録順序**
   - Publisher 側でサブスクリプションを登録してからスナップショット生成
   - その後に Subscriber 側でプルサブスクリプションを作成

5. **Distribution Agent は自動実行**
   - `subscriber-setup.sql` で Distribution Agent ジョブが自動的に作成されます
   - バックグラウンドで継続的にトランザクションを取得します

## プルサブスクリプションの利点

- ✅ **分散制御**: Subscriber が独立してデータを取得
- ✅ **間欠稼働対応**: Subscriber がオフラインでも Publisher に影響なし
- ✅ **スケーラビリティ**: 複数の Subscriber を簡単に追加可能
- ✅ **負荷分散**: Publisher 側の負荷が軽減

## 参考情報

詳細な検証結果は `VERIFICATION-RESULTS.md` の「プルサブスクリプション検証結果」セクションを参照してください。

EXEC sp_add_jobstep
    @job_name = N'Pull Replication Job',
    @step_name = N'Run Distribution Agent',
    @subsystem = N'TSQL',
    @command = N'EXEC distribution.dbo.sp_MSdistribution_agent @publisher=''publisher'', @publisher_db=''ReplicationDB'', @publication=''ProductPublication'', @subscriber=''subscriber'', @subscriber_db=''ReplicationDB'', @subscription_type=1;',
    @database_name = N'ReplicationDB';
GO

EXEC dbo.sp_add_schedule
    @schedule_name = N'Every 5 Minutes',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 4,
    @freq_subday_interval = 5;
GO

EXEC sp_attach_schedule
    @job_name = N'Pull Replication Job',
    @schedule_name = N'Every 5 Minutes';
GO

EXEC dbo.sp_add_jobserver
    @job_name = N'Pull Replication Job';
GO
```

## トラブルシューティング

### サブスクリプションの状態確認

```powershell
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d ReplicationDB -Q "SELECT * FROM dbo.MSsubscription_properties;" -C
```

### Publisher への接続確認

```powershell
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -Q "SELECT * FROM sys.servers WHERE name = 'publisher';" -C
```

### リンクサーバーのテスト

```powershell
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -Q "SELECT * FROM OPENQUERY(publisher, 'SELECT @@SERVERNAME AS ServerName');" -C
```

## クリーンアップ

環境を初期化する場合:

```powershell
docker-compose down -v
```

これによりコンテナ、ネットワーク、およびボリュームがすべて削除されます。

## プッシュサブスクリプションとの比較

| 項目 | プルサブスクリプション | プッシュサブスクリプション |
|------|---------------------|----------------------|
| Distribution Agent | Subscriber 側 | Publisher 側 |
| 制御 | 各 Subscriber が制御 | Publisher が一括制御 |
| Subscriber オフライン時 | 再起動後に取得可能 | 配信失敗 |
| ネットワーク負荷 | Subscriber 起動時のみ | 常時接続が必要 |
| 管理複雑度 | 各 Subscriber で設定 | 中央で一括管理 |
| 適用環境 | 間欠稼働システム | 常時稼働システム |
