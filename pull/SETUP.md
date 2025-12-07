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

### 3. スナップショットの作成

初回同期のためにスナップショットを作成します。

```powershell
docker exec -it sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d ReplicationDB -Q "EXEC sp_startpublication_snapshot @publication = N'ProductPublication';" -C
```

**期待される出力**:
```
Command completed successfully.
```

スナップショットが完了するまで数秒待ちます。

### 4. Subscriber のセットアップ

Subscriber 側でデータベース、テーブル、およびプルサブスクリプションを作成します。

```powershell
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -i /var/opt/mssql/pull-subscriber-setup.sql -C
```

**期待される出力**:
```
ReplicationDB created successfully on Subscriber.
Products table created successfully on Subscriber.
Linked server to Publisher created.
Pull subscription created successfully on Subscriber.
Subscriber setup completed!
```

### 5. Distribution Agent の手動実行

プルサブスクリプションでは、Subscriber 側で Distribution Agent を実行します。

```powershell
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d ReplicationDB -Q "EXEC sp_MSreplication_agentproperties 'publication', 'ProductPublication';" -C
```

初回同期を実行:

```powershell
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -Q "EXEC distribution.dbo.sp_MSdistribution_agent @publisher='publisher', @publisher_db='ReplicationDB', @publication='ProductPublication', @subscriber='subscriber', @subscriber_db='ReplicationDB', @subscription_type=1;" -C
```

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

Subscriber 側で Distribution Agent を再実行してデータを取得します。

```powershell
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -Q "EXEC distribution.dbo.sp_MSdistribution_agent @publisher='publisher', @publisher_db='ReplicationDB', @publication='ProductPublication', @subscriber='subscriber', @subscriber_db='ReplicationDB', @subscription_type=1;" -C
```

Subscriber 側で確認します。

```powershell
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d ReplicationDB -Q "SELECT * FROM Products WHERE ProductName = 'Webcam';" -C
```

新しいレコードが表示されればレプリケーション成功です。

## 自動化オプション

### SQL Server Agent ジョブの作成

Distribution Agent を定期的に実行する SQL Server Agent ジョブを作成できます:

```sql
USE msdb;
GO

EXEC dbo.sp_add_job
    @job_name = N'Pull Replication Job';
GO

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
