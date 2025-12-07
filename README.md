# Master Update Proposal

## 初期プロジェクト説明
このプロジェクトは、ソフトウェア開発におけるベストプラクティスと効果的なリソース管理を実証することを目的としています。

## 提案された改善点
- パフォーマンス指標の強化
- より良いユーザーエクスペリエンスのためのユーザーインターフェースの改善
- データ処理を扱うためのより効率的なアルゴリズムの実装

## SQL Server レプリケーション環境

このリポジトリには、SQL Server トランザクションレプリケーション（Publisher/Subscriber 構成）をテストするための完全な Docker ベースの環境が含まれています。

### レプリケーション方式の選択

このプロジェクトは**プッシュサブスクリプション**と**プルサブスクリプション**の2つの方式を提供しています。
使用環境に応じて適切な方式を選択してください。

#### 📤 プッシュサブスクリプション（Push Subscription）

**推奨環境**: Subscriber が**常時稼働**している場合

- Distribution Agent が Publisher 側で動作
- Publisher が Subscriber へデータを"押し出す"
- 中央集中管理で複数 Subscriber を一括制御
- リアルタイム性が高い

**セットアップ手順**: [SETUP-PUSH.md](SETUP-PUSH.md) を参照

```powershell
# 1. コンテナ起動
docker-compose up -d

# 2. Subscriber セットアップ
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -i /var/opt/mssql/subscriber-setup-push.sql -C

# 3. Publisher セットアップ
docker exec -it sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -i /var/opt/mssql/publisher-setup-push.sql -C

# 4. スナップショット開始
docker exec -it sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d ReplicationDB -Q "EXEC sp_startpublication_snapshot @publication = N'ProductPublication';" -C
```

---

#### 📥 プルサブスクリプション（Pull Subscription）

**推奨環境**: Subscriber が**間欠的に稼働**する場合（各部門サーバーなど）

- Distribution Agent が Subscriber 側で動作
- Subscriber が Publisher からデータを"引き出す"
- 各 Subscriber が独立して同期タイミングを制御
- Subscriber がオフラインでも Publisher に影響なし

**セットアップ手順**: [SETUP-PULL.md](SETUP-PULL.md) を参照

```powershell
# 1. コンテナ起動
docker-compose up -d

# 2. Publisher セットアップ
docker exec -it sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -i /var/opt/mssql/publisher-setup-pull.sql -C

# 3. スナップショット作成
docker exec -it sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d ReplicationDB -Q "EXEC sp_startpublication_snapshot @publication = N'ProductPublication';" -C

# 4. Subscriber セットアップ
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -i /var/opt/mssql/subscriber-setup-pull.sql -C

# 5. Distribution Agent 実行（Subscriber 側）
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -Q "EXEC distribution.dbo.sp_MSdistribution_agent @publisher='publisher', @publisher_db='ReplicationDB', @publication='ProductPublication', @subscriber='subscriber', @subscriber_db='ReplicationDB', @subscription_type=1;" -C
```

---

### 方式比較表

| 項目 | プッシュサブスクリプション | プルサブスクリプション |
|------|---------------------|----------------------|
| **Distribution Agent の場所** | Publisher 側 | Subscriber 側 |
| **制御方式** | 中央集中型 | 分散型 |
| **Subscriber の稼働要件** | 常時稼働が必要 | 間欠稼働でも可 |
| **Subscriber オフライン時** | 配信失敗（エラー発生） | 再起動後に取得可能 |
| **リアルタイム性** | 高い（即座に配信） | 中程度（取得タイミング依存） |
| **管理の複雑度** | 低い（中央管理） | 中程度（各 Subscriber で設定） |
| **ネットワーク負荷** | 常時接続必要 | Subscriber 起動時のみ |
| **適用例** | 中央サーバー→部門サーバー（常時稼働） | 部門間連携（夜間停止） |

---

### 動作確認方法

どちらの方式でも、以下のコマンドでレプリケーションをテストできます。

```powershell
# Publisher にデータを挿入
docker exec -it sqlpublisher /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d ReplicationDB -Q "INSERT INTO Products (ProductName, Price) VALUES ('Webcam', 59.99);" -C

# Subscriber で確認（プッシュの場合は自動、プルの場合は Agent 実行後）
docker exec -it sqlsubscriber /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d ReplicationDB -Q "SELECT * FROM Products WHERE ProductName = 'Webcam';" -C
```

---

### 含まれるファイル

**Docker 環境**:
- **docker-compose.yml**: Publisher と Subscriber の SQL Server コンテナを設定

**プッシュサブスクリプション用**:
- **publisher-setup-push.sql**: Publisher、配布データベース、パブリケーション、およびプッシュサブスクリプションをセットアップ
- **subscriber-setup-push.sql**: Subscriber のデータベースとテーブルスキーマをセットアップ
- **SETUP-PUSH.md**: プッシュサブスクリプションの詳細セットアップ手順

**プルサブスクリプション用**:
- **publisher-setup-pull.sql**: Publisher、配布データベース、およびパブリケーションをセットアップ
- **subscriber-setup-pull.sql**: Subscriber のデータベース、テーブル、およびプルサブスクリプションをセットアップ
- **SETUP-PULL.md**: プルサブスクリプションの詳細セットアップ手順

**ドキュメント**:
- **REPLICATION-README.md**: レプリケーションの概念と詳細な技術情報
- **VERIFICATION-RESULTS.md**: プッシュサブスクリプションでの検証結果

---

### クリーンアップ

環境を初期化する場合:

```powershell
docker-compose down -v
```

これによりコンテナ、ネットワーク、およびボリュームがすべて削除されます。