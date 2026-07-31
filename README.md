# RoleWeave

自己ホスト可能な採用プラットフォームの OSS 実装です。

日本語 | [English](README.en.md)

## 現在の状態

**開発中であり、本番利用を推奨する段階ではありません。**

このリポジトリは開発の初期段階にあります。
Railsアプリケーションの基盤は存在しますが、求人、応募、認証などの業務機能はまだ実装されていません。
互換性のない変更を予告なく行う可能性があります。

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
何度実行しても同じ状態へ収束するため、再実行できます。
既存の development データベースの内容も、追跡対象のファイルも変更しません。

### 起動する

```bash
docker compose up
```

現段階では業務画面と root route を実装していないため、トップページはありません。
稼働確認にはヘルスチェックを使用します。

```text
http://127.0.0.1:3000/up
```

ホスト側のポートを変更する場合は `APP_PORT` を指定します。

```bash
APP_PORT=3001 docker compose up
```

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

```bash
bundle install
bin/verify --full
```

完全検証は `Gemfile` と `Gemfile.lock` が作業ツリーで変更されていないことを確認します。
依存を更新した場合は、コミットしてから実行してください。

## ドキュメント

- [プロジェクト概要](docs/project-overview.md) — 何を、誰のために作るか
- [プロジェクト原則](docs/project-principles.md) — 計画・実装上の判断を導く基本原則
- [ロードマップ](docs/roadmap/index.yaml) — P0 から P15 までのフェーズ索引
- [アーキテクチャ原則](docs/architecture/principles.md) — 構造に関する判断基準
- [開発言語・命名ポリシー](docs/development/language-policy.md) — 日本語と英語の使い分け
- [コーディングスタイル](docs/development/coding-style.md) — 実装中に参照する言語・コメント・構造の要点
- [開発工程](docs/development/workflow.md) — ロードマップ・Issue・PR・ADR の責務
- [横断品質要件](docs/quality/cross-cutting-requirements.md) — 各機能フェーズで同時に満たす品質要件

## 開発の進め方

中長期計画はロードマップ、実行タスクと不具合は GitHub Issues、
実装内容と検証結果は Pull Request を正本としています。
1 Issue につき 1 つの確認可能な成果、1 PR を原則としています。
詳細は[開発工程](docs/development/workflow.md)を参照してください。

## ライセンス

[Apache License 2.0](LICENSE)

Copyright 2026 Pocket (@toshtag)
