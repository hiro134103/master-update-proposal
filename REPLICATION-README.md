# Docker Compose を使用した SQL Server レプリケーション環境

このリポジトリは、Docker Compose を使用して SQL Server レプリケーションをテストするための完全なローカル開発環境を提供します。セットアップには、トランザクションレプリケーションを使用した Publisher と Subscriber の構成が含まれています。

## 目次
- [前提条件](#前提条件)
- [プロジェクト構造](#プロジェクト構造)
- [クイックスタート](#クイックスタート)
- [詳細なセットアップ手順](#詳細なセットアップ手順)
- [レプリケーションのテスト](#レプリケーションのテスト)
- [トラブルシューティング](#トラブルシューティング)
- [クリーンアップ](#クリーンアップ)

## 前提条件

開始する前に、システムに以下がインストールされていることを確認してください：
- Docker (バージョン 20.10 以降)
- Docker Compose (バージョン 1.29 以降)
- SQL クライアントツール (SQL Server Management Studio、Azure Data Studio、または sqlcmd)

## プロジェクト構造

```
.
├── docker-compose.yml              # Publisher と Subscriber の Docker Compose 設定
├── push-replication/               # プッシュサブスクリプション
│   ├── SETUP.md                    # セットアップ手順
│   ├── VERIFICATION-RESULTS.md     # 検証結果
│   ├── publisher-setup.sql         # Publisher 設定スクリプト
│   └── subscriber-setup.sql        # Subscriber 設定スクリプト
├── pull-replication/               # プルサブスクリプション
│   ├── SETUP.md                    # セットアップ手順
│   ├── VERIFICATION-RESULTS.md     # 検証結果
│   ├── publisher-setup.sql         # Publisher 設定スクリプト
│   └── subscriber-setup.sql        # Subscriber 設定スクリプト
├── ARCHITECTURE.md                 # アーキテクチャ詳細説明
├── README.md                       # メインの README
└── REPLICATION-README.md           # このファイル
```

## アーキテクチャ

レプリケーションの技術的な詳細については、以下をご覧ください：
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - プッシュ/プルサブスクリプションのデータフロー、データベース構成、比較表

## クイックスタート

### 1. Docker環境の起動

```bash
# コンテナを起動
docker-compose up -d

# コンテナの準備を待つ（約30-60秒）
docker-compose ps
```

### 2. レプリケーション設定

**プッシュサブスクリプション:**
詳細は [push-replication/SETUP.md](push-replication/SETUP.md) を参照

**プルサブスクリプション:**
詳細は [pull-replication/SETUP.md](pull-replication/SETUP.md) を参照

---

## 詳細なセットアップ手順

各レプリケーション方式の詳しいセットアップ手順は、それぞれのフォルダにある SETUP.md を参照してください：

- **プッシュサブスクリプション**: [push-replication/SETUP.md](push-replication/SETUP.md)
- **プルサブスクリプション**: [pull-replication/SETUP.md](pull-replication/SETUP.md)

---

## レプリケーションのテスト

### 初期データレプリケーションの確認

1. **Subscriber のデータを確認:**

```bash
# Subscriber に接続して Products テーブルをクエリ
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d ReplicationDB -Q "SELECT * FROM Products;" -C
```

Publisher に挿入された同じ 5 つの製品が表示されるはずです。

### リアルタイムレプリケーションのテスト

1. **Publisher に新しい製品を挿入:**

```bash
docker exec -it sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d ReplicationDB -Q "INSERT INTO Products (ProductName, Price) VALUES ('Webcam', 149.99);" -C
```

2. **Publisher で既存の製品を更新:**

```bash
docker exec -it sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d ReplicationDB -Q "UPDATE Products SET Price = 899.99 WHERE ProductName = 'Laptop';" -C
```

3. **Publisher で製品を削除:**

```bash
docker exec -it sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d ReplicationDB -Q "DELETE FROM Products WHERE ProductName = 'Mouse';" -C
```

4. **Subscriber で変更を確認（レプリケーションのために数秒待機）:**

```bash
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d ReplicationDB -Q "SELECT * FROM Products ORDER BY ProductID;" -C
```

Subscriber は Publisher で行われたすべての変更を反映するはずです。

### レプリケーションステータスの監視

レプリケーションステータスとエラーを確認：

```bash
# Publisher 側 - Distribution Agent の履歴を確認
docker exec sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d distribution -Q "SELECT TOP 10 time, comments FROM MSdistribution_history ORDER BY time DESC;" -C

# レプリケーションエラーを確認
docker exec sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d distribution -Q "SELECT * FROM MSrepl_errors ORDER BY time DESC;" -C
```

## トラブルシューティング

### よくある問題

**1. コンテナが起動しない:**
- Docker が実行中であることを確認
- ポート 1433 と 1434 が利用可能か確認
- コンテナログを確認: `docker-compose logs`

**2. SQL Server Agent が実行されていない:**
```bash
# Publisher で SQL Server Agent のステータスを確認
docker exec sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -Q "SELECT CASE WHEN EXISTS(SELECT 1 FROM sys.dm_exec_sessions WHERE program_name LIKE 'SQLAgent%') THEN 'Running' ELSE 'Not Running' END AS AgentStatus;" -C

# 必要に応じて、エージェントジョブが存在することを確認
docker exec sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d msdb -Q "SELECT job_id, name, enabled FROM sysjobs WHERE name LIKE '%snapshot%' OR name LIKE '%repl%';" -C
```

**3. レプリケーションが動作しない:**
- スナップショットが正常に生成されたことを確認
- SQL Server Agent ジョブが実行中であることを確認
- レプリケーションモニターでエラーを確認
- 両方のコンテナが `sql_repl_network` 上で通信できることを確認

**4. Publisher と Subscriber 間の接続問題:**
```bash
# ネットワーク接続をテスト
docker exec sqlsubscriber ping sqlpublisher
```

**5. 詳細なレプリケーションエラーを表示:**
```bash
docker exec sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d distribution -Q "SELECT TOP 5 time, error_id, comments FROM MSdistribution_history WHERE error_id <> 0 ORDER BY time DESC;" -C
```

### 環境をリセットしてやり直す

環境を完全にリセットする必要がある場合：

```bash
# コンテナ、ネットワーク、およびボリュームを停止して削除
docker-compose down -v

# 新たに開始
docker-compose up -d

# セットアップスクリプトを再実行
```

## クリーンアップ

すべてのコンテナ、ネットワーク、およびボリュームを停止して削除するには：

```bash
# すべてを停止して削除
docker-compose down -v

# またはコンテナのみを停止（データを保持）
docker-compose stop
```

コンテナのみを削除してボリュームを保持するには：

```bash
docker-compose down
```

## 追加リソース

- [SQL Server レプリケーションドキュメント](https://docs.microsoft.com/ja-jp/sql/relational-databases/replication/sql-server-replication)
- [Docker Compose ドキュメント](https://docs.docker.com/compose/)
- [Docker 上の SQL Server](https://docs.microsoft.com/ja-jp/sql/linux/sql-server-linux-overview)

## セキュリティに関する注意

⚠️ **重要:** このセットアップは、デモンストレーション目的で簡単なパスワード（`YourStrong@Passw0rd`）を使用しています。本番環境では：
- 強力でユニークなパスワードを使用
- パスワードを安全に保管（例: Docker secrets を使用）
- 適切なネットワークセキュリティを設定
- SQL Server 接続用の SSL/TLS 暗号化を有効化
- SQL Server アカウントには最小権限の原則に従う

## ライセンス

このプロジェクトは、教育および開発目的のために現状のまま提供されます。
