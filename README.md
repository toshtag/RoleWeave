# RoleWeave

自己ホスト可能な採用プラットフォームの OSS 実装です。

日本語 | [English](README.en.md)

## 現在の状態

**評価できる状態です。本番運用を保証する段階ではありません。**

公開している最新のリリースは `v0.1.0` です。
現在の `main` には、`v0.1.0` の後に追加した機能と修正が入っています。
これらにはまだ版を付けていないため、リリースとしては出していません。

計画していた P0 から P15 までのフェーズは、すべて完了しています。

現在の `main` で実装している範囲は次のとおりです。

| 範囲 | 内容 |
| --- | --- |
| アカウント | 登録、メールの確認、ログイン、パスワード再設定、認証の記録 |
| 組織 | 組織の作成、招待、役割（管理者・一般）、権限の変更の履歴、運営者 |
| 求人 | 作成・編集、申請と承認の分離、公開状態の履歴 |
| 公開 | 求人の一覧・詳細、キーワードと条件の絞り込み、ページ分割、sitemap・robots、構造化データ |
| プロフィール | 基本情報、職歴、学歴、スキル、希望条件、履歴書の添付、公開範囲 |
| 応募 | 応募、二重応募の防止、応募時点の写し、取消、企業側からの閲覧 |
| 選考 | 選考の段階、評価とコメント、担当者、面接の予定、結論の期限 |
| 連絡 | 応募に紐づく会話、既読、アプリ内通知、メール通知、配信の失敗と再送 |
| 保存と発掘 | 求人の保存、検索条件の保存、新着の通知、候補者検索、タレントプール |
| スカウト | 送信、テンプレート、送信の上限、配信停止、重複送信の防止 |
| 外部連携 | 汎用 Webhook、求人の CSV 入出力、連携の実行履歴 |
| 安全 | レート制限、CSP、逆プロキシの前提、入力の大きさの上限、保持期限、削除と匿名化、監査ログ |
| 運用 | 構造化ログ、遅い SQL の記録、負荷試験、容量モデル、バックアップ手順 |
| 評価 | 架空データのデモ、ロール別の手順、アーキテクチャの概要 |

候補者検索とスカウトの対象になるのは、**求職者が受信を許可した場合だけ**です。
既定では許可していません（[ADR 0055](docs/decisions/0055-candidate-search.md)）。

まだ入っていないものと既知の制限は[変更の履歴](CHANGELOG.md)に、
満たしていない品質要件は
[横断品質要件の検証状況](docs/known-gaps.md)に書いています。

`0.x` の間は、互換性のない変更が入りうる状態です。

## このプロジェクトについて

求人情報の公開、求人検索、候補者プロフィール、応募、選考、スカウト、メッセージ、通知、
外部連携を扱う採用プラットフォームを、自己ホスト可能な OSS として開発します。

想定している読み手は、採用データを自組織の管理下に置きたい企業・団体と、
その環境を構築・運用する開発者です。
成功条件は機能の網羅数ではなく、変更容易性・安全性・再現可能性に置いています。

### ゼロベースで開発しています

既存アプリケーションからコード、データベース構造、ルーティング、命名、
ディレクトリ構成を移植していません。
既存資料は、必要な機能を把握するための参考情報としてのみ利用します。

### 日本語と英語に対応します

利用者向けの表示（UI）、公開仕様、セットアップ手順、操作文書は、
日本語と英語の両方を提供します。
内部設計、ADR、タスク定義、検証結果は日本語を正本とし、英訳は必須としません
（[開発言語・命名ポリシー](docs/development/language-policy.md)）。

### 常設デモは提供しません

現段階では、常設のデモ環境や公開ホスティングを提供しません。
評価はローカル環境で行うことを想定しています。

## 技術スタック

- Ruby on Rails 8.1 によるモジュラーモノリス（Puma）
- PostgreSQL 18 を正本データベースとする
- サーバーサイドレンダリング、Turbo、Stimulus、Propshaft、Importmap
- Solid Queue、Solid Cache、Active Storage（Disk）
- Docker Compose によるローカル開発環境、GitHub Actions による検証

**Redis、OpenSearch、Kubernetes、外部の CDN を使いません。**
自己ホストできることを前提に選んでいます
（[アーキテクチャの概要](docs/architecture.md)）。

## セットアップ

通常のローカル開発は Docker Compose だけで開始できます。

### 必要なもの

- Git
- Docker Engine または Docker Desktop
- Docker Compose v2

通常の開発では、次をホストへ導入する必要はありません。

- Ruby
- PostgreSQL
- Node.js
- npm

### リポジトリを取得する

```bash
git clone https://github.com/toshtag/RoleWeave.git
cd RoleWeave
```

### イメージを構築する

```bash
docker compose build app
```

取得した `.deb` と `.gem` は BuildKit の cache mount にあり、
イメージには残りません。次のビルドでは取り直しません。

キャッシュが溜まって容量を戻したいときは `docker builder prune` を実行します。
**これは他のプロジェクトの分も消します。**

### 初期セットアップ

```bash
docker compose run --rm app bin/setup
```

依存関係の確認、development データベースの準備、古いログと一時ファイルの整理を行います。
開発サーバーは起動しません。起動は `docker compose up` の責務です。

**既存のデータベースを drop も reset もしません。**
未適用の migration があれば適用するため、その定義に従って中身が変わることはあります。
何度実行しても同じ開発可能な状態へ収束します。

### 起動する

```bash
docker compose up
```

日本語と英語の入口を提供します。

```text
http://127.0.0.1:3000/ja
http://127.0.0.1:3000/en
```

`/` は日本語のページへリダイレクトします。
公開の求人一覧は `/ja/jobs`、ログインは `/ja/session/new`、
アカウントの作成は `/ja/registration/new` です。
ロール別の入口は[求職者として使う](docs/guides/candidate.md)と
[企業の担当者として使う](docs/guides/organization.md)にまとめています。

稼働確認用のヘルスチェックも引き続き利用できます。

```text
http://127.0.0.1:3000/up
```

ホスト側のポートを変更する場合は `APP_PORT` を指定します。

```bash
APP_PORT=3001 docker compose up
```

### デモデータを投入する

評価のための架空データを入れます。development でのみ実行できます。

```bash
docker compose run --rm app bin/rails roleweave:demo:seed
```

投入したアカウントとパスワードが出力されます。
メールアドレスはすべて `@example.invalid`（実在しない領域）です。

消すときは次を実行します。

```bash
docker compose run --rm app bin/rails roleweave:demo:clean
```

運営者権限の付与、保持期限の適用、性能の測定は
[運営者として使う](docs/guides/operator.md)にまとめています。

### 標準検証

```bash
docker compose run --rm app bin/verify
```

依存関係の確認、セキュリティ検査、Ruby スタイル、Zeitwerk、Rails test を実行します。
依存関係のインストール、development データベースの変更、サーバーの起動は行いません。

bundler-audit は advisory database を更新してから監査するため、外部通信が必要です。

### 停止する

前景で起動している場合は `Ctrl+C` で停止します。
コンテナを停止して削除するには次を実行します。

```bash
docker compose down
```

開発データも削除する場合は `--volumes` を付けます。**これは破壊的な操作です。**
PostgreSQL の永続データと bundle キャッシュの named volume が削除され、
development データベースの内容は失われます。

```bash
docker compose down --volumes
```

### 完全検証

`bin/verify --full` は、Docker 基盤と `bin/setup` の冪等性を含む P0 の完全検証です。
保守者向けであり、通常の開発では必要ありません。

標準検証と異なりホスト側で直接実行するため、
`.ruby-version` の Ruby（4.0.6）、Bundler、Docker、
および Bash と一般的な Unix コマンド（macOS、Linux、WSL、Git Bash など）が必要です。
ネイティブの PowerShell やコマンドプロンプトだけでの実行は対象外です。

```bash
bundle install
bin/verify --full
```

`Gemfile` と `Gemfile.lock` が作業ツリーで変更されていると失敗します。
依存を更新した場合は、コミットしてから実行してください。

## ドキュメント

### 使う

- [求職者として使う](docs/guides/candidate.md) — 登録から応募・退会まで
- [企業の担当者として使う](docs/guides/organization.md) — 組織・求人・選考
- [運営者として使う](docs/guides/operator.md) — サーバーを運用する人向け

### 運用する

- [バックアップと復元](docs/operations/backup-and-restore.md) — データベースと添付を組で扱う
- [逆プロキシの前提](docs/operations/reverse-proxy.md) — 前段に求める条件と、満たさない場合に効かなくなるもの
- [ファイルの保存先](docs/operations/file-storage.md) — 添付の保存先と自己ホストでの運用
- [負荷試験の実測値](docs/operations/load-test-results.md) — 測った値だけを書く
- [容量モデル](docs/operations/capacity-model.md) — 前提を明示した見積もり

### 開発する

- [開発に参加する](CONTRIBUTING.md) — 進め方と検証の要求
- [アーキテクチャの概要](docs/architecture.md) — 何がどう組み合わさっているか
- [開発の原則](docs/principles.md) — 計画・実装・コードの判断基準
- [開発工程](docs/development/workflow.md) — Issue・PR・検証・ADR の責務
- [開発言語・命名ポリシー](docs/development/language-policy.md) — 日本語と英語の使い分け
- [リリース手順](docs/development/release.md) — 版の付け方と出す前の確認
- [判断の記録](docs/decisions/) — ADR 67 件。知りたいことからの引き方は[アーキテクチャの概要](docs/architecture.md)にある

### 何ができていないかを知る

- [変更の履歴](CHANGELOG.md) — 版ごとの内容と既知の制限
- [満たしていない品質要件](docs/known-gaps.md) — 満たしている点と満たしていない点
- [脅威モデル](docs/threat-model.md) — 何から守り、何を受け入れているか
- [セキュリティ報告手順](SECURITY.md) — 問題を見つけたときの連絡先
- [v1 以降の検討候補](docs/decisions/0059-post-v1-evaluation.md) — 実装の約束ではない候補の一覧と評価の手順

## 開発の進め方

実行タスクと不具合は GitHub Issues、実装内容と検証結果は Pull Request を正本としています。
1 Issue につき 1 つの確認可能な成果、1 PR を原則としています。
詳細は[開発工程](docs/development/workflow.md)を参照してください。

**計画していたフェーズ（P0 から P15）は完了しています。**
以降は、新しい機能を計画に沿って足し続けることはしません。
具体的な不具合の報告か、実際の利用にもとづく要望があった時点で Issue を作り、
個別に判断します（[ADR 0059](docs/decisions/0059-post-v1-evaluation.md)）。

## ライセンス

[Apache License 2.0](LICENSE)

Copyright 2026 Pocket (@toshtag)
