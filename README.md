# Master Update Proposal

## 初期プロジェクト説明
このプロジェクトは、ソフトウェア開発におけるベストプラクティスと効果的なリソース管理を実証することを目的としています。

## 提案された改善点
- パフォーマンス指標の強化
- より良いユーザーエクスペリエンスのためのユーザーインターフェースの改善
- データ処理を扱うためのより効率的なアルゴリズムの実装

## SQL Server レプリケーション環境

このリポジトリには、SQL Server レプリケーション（Publisher/Subscriber 構成）をテストするための完全な Docker ベースの環境が含まれています。

### クイックスタート

SQL Server レプリケーション環境を開始するには：

1. **環境を起動:**
   ```bash
   docker-compose up -d
   ```

2. **Publisher を設定:**
   ```bash
   docker exec -it sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -i /var/opt/mssql/publisher-setup.sql -C
   ```

3. **Subscriber を設定:**
   ```bash
   docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -i /var/opt/mssql/subscriber-setup.sql -C
   ```

4. **スナップショットを開始:**
   ```bash
   docker exec sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d ReplicationDB -Q "EXEC sp_startpublication_snapshot @publication = N'ProductPublication';" -C
   ```

5. **レプリケーションをテスト:**
   ```bash
   # Publisher にデータを挿入
   docker exec -it sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d ReplicationDB -Q "INSERT INTO Products (ProductName, Price) VALUES ('Webcam', 149.99);" -C
   
   # Subscriber で確認
   docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d ReplicationDB -Q "SELECT * FROM Products;" -C
   ```

詳細な手順、トラブルシューティング、および高度な使用方法については、[REPLICATION-README.md](REPLICATION-README.md) を参照してください。

### 含まれるファイル

- **docker-compose.yml**: Publisher と Subscriber の SQL Server コンテナを設定
- **publisher-setup.sql**: Publisher、配布データベース、およびパブリケーションをセットアップ
- **subscriber-setup.sql**: Subscriber とサブスクリプションをセットアップ
- **REPLICATION-README.md**: 詳細なセットアップ手順を含む包括的なドキュメント
- **VERIFICATION-RESULTS.md**: レプリケーション検証結果