# RoleWeave

自己ホスト可能な採用プラットフォームの OSS 実装です。

日本語 | [English](README.en.md)

## 現在の状態

**v0.1.0（評価できる状態）です。本番運用を保証する段階ではありません。**

アカウント、組織、求人、公開、プロフィール、応募、選考、連絡、
安全と運用の仕組みまでを実装しています。
入っていないもの（スカウト、外部連携）と既知の制限は
[変更の履歴](CHANGELOG.md)に書いています。

`0.x` の間は、互換性のない変更が入りうる状態です。

## このプロジェクトについて

求人情報の公開、求人検索、候補者プロフィール、応募、選考、スカウト、メッセージ、通知、
外部連携を扱う採用プラットフォームを、自己ホスト可能な OSS として開発します。

### ゼロベースで開発しています

既存アプリケーションからコード、データベース構造、ルーティング、命名、
ディレクトリ構成を移植していません。
既存資料は、必要な機能を把握するための参考情報としてのみ利用します。

### 日本語と英語に対応します

日本語と英語の両方を提供する範囲は次のとおりです。

- 利用者向けの表示（UI）は、初期段階から日本語と英語を同等に扱います
- 公開仕様、セットアップ手順、操作文書は、日本語と英語の両方を提供します

日本語を正本とする範囲は次のとおりです。

- 内部設計、ADR、タスク定義、レビュー記録は日本語を正本とします
- これらすべてに英訳を用意することは必須としません

### 常設デモは提供しません

現段階では、常設のデモ環境や公開ホスティングを提供しません。
評価はローカル環境で行うことを想定しています。

## 技術スタック

初期基準は次のとおりです。各バージョンは初期化時点の安定パッチへ固定します。

- Ruby on Rails によるモジュラーモノリス
- PostgreSQL を正本データベースとする
- サーバーサイドレンダリング、Turbo、Stimulus
- Active Job、Solid Queue、Active Storage
- Docker Compose によるローカル開発環境
- GitHub Actions による検証

初期段階では Redis、OpenSearch、Kubernetes を必須にしません。

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

ベースイメージと依存関係をキャッシュなしで作り直す場合は、次を実行します。
Foundation の再検証で使用するもので、通常の開発では必要ありません。

```bash
docker compose build --no-cache app
```

### 初期セットアップ

```bash
docker compose run --rm app bin/setup
```

`bin/setup` は次を行います。

- Ruby 依存関係を確認し、不足している場合だけ準備する
- development データベースを準備する
- 古いログと一時ファイルを整理する

開発サーバーは起動しません。起動は `docker compose up` の責務です。

`bin/setup` は既存の development データベースを drop または reset しません。
未適用の migration がある場合は適用するため、その migration の定義に従って
データベースのスキーマやデータが変更される場合があります。

同じコードと migration の状態で再実行した場合は、既存のデータベース状態を維持し、
追跡対象のファイルを変更せず、同じ開発可能な状態へ収束します。

### 起動する

```bash
docker compose up
```

Application Shell の最小の入口として、日本語と英語のページを提供します。

```text
http://127.0.0.1:3000/ja
http://127.0.0.1:3000/en
```

`/` は日本語のページへリダイレクトします。
求人、応募、認証などの業務機能はまだ実装していません。

稼働確認用のヘルスチェックも引き続き利用できます。

```text
http://127.0.0.1:3000/up
```

ホスト側のポートを変更する場合は `APP_PORT` を指定します。

```bash
APP_PORT=3001 docker compose up
```

### 運営者権限を与える

このサーバーを運用する担当者へ運営者権限を与えます。画面からは付与できません。

```bash
docker compose run --rm app bin/rails "roleweave:operator:grant[you@example.com]"
```

取り上げる場合は `revoke` を使います。

```bash
docker compose run --rm app bin/rails "roleweave:operator:revoke[you@example.com]"
```

運営者は、すべての組織の一覧と、組織の管理者を立て直す操作だけを行えます。
詳細は [`docs/decisions/0015-operator-role.md`](docs/decisions/0015-operator-role.md) を参照してください。

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

### 負荷試験を実行する

データを作ってから測ります。外部の負荷ツールは要りません。

```bash
docker compose run --rm app bin/rails "roleweave:load:seed[5000]"
```

```bash
docker compose run --rm app bin/rails "roleweave:load:measure[20]"
```

測り終えたら消します。

```bash
docker compose run --rm app bin/rails roleweave:load:clean
```

実測値は [`docs/performance/load-test-results.md`](docs/performance/load-test-results.md)、
見積もりは [`docs/performance/capacity-model.md`](docs/performance/capacity-model.md) にあります。

### 保持期限を適用する

保持期限を過ぎたデータを削除・匿名化します。自動では実行しません。

```bash
docker compose run --rm app bin/rails roleweave:retention:report
```

まず `report` で件数を確認し、そのうえで適用します。

```bash
docker compose run --rm app bin/rails roleweave:retention:apply
```

何をどれだけ残すかは
[`docs/decisions/0046-data-retention.md`](docs/decisions/0046-data-retention.md)
を参照してください。

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

標準検証と異なりホスト側で直接実行するため、次が必要です。

- `.ruby-version` に記載された Ruby（4.0.6）
- Bundler
- Docker Engine または Docker Desktop と Docker Compose v2
- ホスト側の Ruby 依存関係
- Bash と一般的な Unix コマンドを利用できる環境
  （macOS、Linux、または Windows 上の WSL・Git Bash など）

完全検証は Bash スクリプトであり、`awk`、`grep`、`find`、`mktemp`、`tr` などを使用します。
ネイティブの PowerShell やコマンドプロンプトだけでの実行は対象としていません。
この要件は完全検証だけのものであり、通常の Docker 開発には当てはまりません。

```bash
bundle install
bin/verify --full
```

完全検証は `Gemfile` と `Gemfile.lock` が作業ツリーで変更されていないことを確認します。
依存を更新した場合は、コミットしてから実行してください。

## ドキュメント

- [プロジェクト概要](docs/project-overview.md) — 何を、誰のために作るか
- [求職者として使う](docs/guides/candidate.md) — 登録から応募・退会まで
- [企業の担当者として使う](docs/guides/organization.md) — 組織・求人・選考
- [運営者として使う](docs/guides/operator.md) — サーバーを運用する人向け
- [アーキテクチャの概要](docs/architecture/overview.md) — 何がどう組み合わさっているか
- [開発に参加する](CONTRIBUTING.md) — 進め方と検証の要求
- [変更の履歴](CHANGELOG.md) — 版ごとの内容と既知の制限
- [リリース手順](docs/development/release.md) — 版の付け方と出す前の確認
- [プロジェクト原則](docs/project-principles.md) — 計画・実装上の判断を導く基本原則
- [ロードマップ](docs/roadmap/index.yaml) — P0 から P15 までのフェーズ索引
- [v1 以降の検討候補](docs/roadmap/post-v1-options.md) — 実装の約束ではない候補の一覧と評価の手順
- [アーキテクチャ原則](docs/architecture/principles.md) — 構造に関する判断基準
- [開発言語・命名ポリシー](docs/development/language-policy.md) — 日本語と英語の使い分け
- [コーディングスタイル](docs/development/coding-style.md) — 実装中に参照する言語・コメント・構造の要点
- [開発工程](docs/development/workflow.md) — ロードマップ・Issue・PR・ADR の責務
- [ファイルの保存先](docs/development/file-storage.md) — 添付の保存先と自己ホストでの運用
- [逆プロキシの前提](docs/development/reverse-proxy.md) — 前段に求める条件と、満たさない場合に効かなくなるもの
- [横断品質要件](docs/quality/cross-cutting-requirements.md) — 各機能フェーズで同時に満たす品質要件
- [横断品質要件の検証状況](docs/quality/verification-status.md) — 満たしている点と満たしていない点
- [脅威モデル](docs/security/threat-model.md) — 何から守り、何を受け入れているか
- [セキュリティ報告手順](SECURITY.md) — 問題を見つけたときの連絡先
- [バックアップと復元](docs/development/backup-and-restore.md) — データベースと添付を組で扱う
- [負荷試験の実測値](docs/performance/load-test-results.md) — 測った値だけを書く
- [容量モデル](docs/performance/capacity-model.md) — 前提を明示した見積もり

## 開発の進め方

中長期計画はロードマップ、実行タスクと不具合は GitHub Issues、
実装内容と検証結果は Pull Request を正本としています。
1 Issue につき 1 つの確認可能な成果、1 PR を原則としています。
詳細は[開発工程](docs/development/workflow.md)を参照してください。

## ライセンス

[Apache License 2.0](LICENSE)

Copyright 2026 Pocket (@toshtag)
