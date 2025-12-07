# Master Update Proposal

## プロジェクト概要

このプロジェクトは、SQL Server トランザクションレプリケーション（Publisher/Subscriber 構成）をテストするための完全な Docker ベースの環境を提供します。

## ドキュメント構成

- **[REPLICATION-README.md](REPLICATION-README.md)** - Docker環境のセットアップとテスト手順
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - レプリケーションアーキテクチャの詳細説明
- **[push-replication/](push-replication/)** - プッシュサブスクリプション関連ファイル
- **[pull-replication/](pull-replication/)** - プルサブスクリプション関連ファイル

## レプリケーション方式の選択

### 📤 プッシュサブスクリプション

**推奨環境**: Subscriber が**常時稼働**している場合

**特徴:**
- Distribution Agent が Publisher 側で動作
- 中央集中管理で複数 Subscriber を一括制御
- リアルタイム性が高い（5分間隔のデフォルト）

**詳細**: [push-replication/SETUP.md](push-replication/SETUP.md)

---

### 📥 プルサブスクリプション

**推奨環境**: Subscriber が**間欠的に稼働**する場合（夜間停止する部門サーバーなど）

**特徴:**
- Distribution Agent が Subscriber 側で動作
- 各 Subscriber が独立して同期タイミングを制御
- Subscriber がオフラインでも Publisher に影響なし
- 起動順序に依存しない

**詳細**: [pull-replication/SETUP.md](pull-replication/SETUP.md)

---

### 比較表

| 項目 | プッシュサブスクリプション | プルサブスクリプション |
|------|---------------------|----------------------|
| **Distribution Agent の場所** | Publisher側 | Subscriber側 |
| **接続方向** | Publisher → Subscriber | Subscriber → Publisher |
| **配信タイミング** | Publisher主導（5分間隔） | Subscriber主導（30分間隔推奨） |
| **Subscriber停止時** | 配信エラーが発生 | 次回起動時に自動取得 |
| **起動順序依存** | Subscriberが先に起動不可 | どちらが先でも問題なし |
| **リアルタイム性** | 高い | 中程度 |
| **管理の複雑度** | 低い（中央管理） | 中程度（各Subscriber設定） |

詳しい技術比較は **[ARCHITECTURE.md](ARCHITECTURE.md)** を参照してください。

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

## クイックスタート

### 1. Docker環境を起動

```powershell
docker-compose up -d
docker-compose ps  # コンテナの状態確認
```

### 2. レプリケーション方式を選択

- **プッシュサブスクリプション**: [push-replication/SETUP.md](push-replication/SETUP.md)
- **プルサブスクリプション**: [pull-replication/SETUP.md](pull-replication/SETUP.md)

---

## プロジェクト構造

```
.
├── docker-compose.yml              # Docker環境定義
├── README.md                       # このファイル
├── REPLICATION-README.md           # 詳細セットアップガイド
├── ARCHITECTURE.md                 # アーキテクチャ説明
├── push-replication/
│   ├── SETUP.md
│   ├── VERIFICATION-RESULTS.md
│   ├── publisher-setup.sql
│   └── subscriber-setup.sql
└── pull-replication/
    ├── SETUP.md
    ├── VERIFICATION-RESULTS.md
    ├── publisher-setup.sql
    └── subscriber-setup.sql
```

---

## クリーンアップ

環境を完全に削除する場合:

```powershell
docker-compose down -v
```

---

## セキュリティに関する注意

⚠️ このセットアップは**検証・開発目的**です。本番環境では：
- 強力なパスワードを使用
- SSL/TLS 暗号化を有効化
- 最小権限の原則に従った権限設定
- パスワードを環境変数や Docker Secrets で管理