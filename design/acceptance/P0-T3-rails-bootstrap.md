# P0-T3 受け入れ条件 — Rails アプリケーションの生成

この文書は P0-T3 の受け入れ条件の正本とする。
P0-T3 の実装者は、着手前にこの文書を読み、完了報告でここの各項目に対する結果を示す。

## 目的

既存の OSS 文書と Code Pact 制御面を保持しながら、リポジトリ直下へ最小の Rails アプリケーションを生成する。

## 生成方針

- 既存リポジトリへ `rails new . --force` を直接実行しない
- リポジトリ外の一時ディレクトリへ Rails アプリを生成する
- 生成物から許可されたファイルだけをリポジトリへコピーする
- 既存の README、LICENSE、`design/`、`docs/`、Node.js 設定を上書きしない
- アプリケーション設定名前空間は `RoleWeave` とする
- 業務モデルの親名前空間には `RoleWeave` を使わない
- PostgreSQL を指定する
- Git 初期化を行わない
- Docker 関連ファイルを生成しない
- CI 設定を生成しない
- デプロイ設定を導入しない
- Hotwire、Active Job、Active Storage、Action Mailer、Minitest は維持する
- React、Next.js、GraphQL、Redis、OpenSearch を追加しない

Rails 生成前に、使用する Rails バージョンの `rails new --help` を確認する。
最低限、次に相当するオプションを使用する。

```text
--name=RoleWeave
--database=postgresql
--skip-git
--skip-docker
```

利用中の Rails に CI またはデプロイ設定を省略する専用オプションがある場合は、それも使用する。

## 正の検証

- `Gemfile` に `pg` がある
- `config/database.yml` が PostgreSQL を使用する
- `config/application.rb` のアプリケーション名前空間が `RoleWeave`
- `bundle check` が成功する
- `bundle exec rails zeitwerk:check` が成功する
- Rails application の boot が成功する
- Rails 標準のテストディレクトリが存在する
- 既存の Code Pact 検証が成功する

`bundle exec rails zeitwerk:check` と boot 確認は、PostgreSQL が起動していない環境で実行することになる。
P0-T4 まで PostgreSQL は導入しないため、これらが接続を要求して失敗する場合は、
接続を伴わない boot 確認へ置き換えるか、接続を要する検証を P0-T4 へ移す。
どちらを選んだかを完了報告に記載する。検証を無効化したまま完了としない。

## 負の検証

- README、LICENSE、`design/`、`docs/`、`package.json`、`package-lock.json` が変更されていない
- Docker 関連ファイル（`Dockerfile`、`compose.yaml`、`docker-compose.yml`、`.dockerignore`、
  `bin/docker-entrypoint`、`.devcontainer/`）がない
- GitHub Actions workflow がない
- `.devcontainer` がない
- 旧システム由来の固有名詞がない
- React、Next.js、Redis、OpenSearch が追加されていない
- 将来用の空ディレクトリを作っていない
- 求人、応募、認証などの業務機能を実装していない

## 自動検証との対応

上記のうち機械的に確認できる項目は `scripts/verify-p0` に実装済みで、
P0-T3 の `started` イベントが記録された時点から自動的に有効になる。

- Rails 実体の存在確認（`Gemfile` / `Gemfile.lock` / `Rakefile` / `config.ru` / `bin/rails` /
  `config/application.rb` / `config/database.yml` / `app/` / `test/`）
- `pg` gem、`adapter: postgresql`、`module RoleWeave` の宣言確認
- `bundle check`、`zeitwerk:check`、アプリケーション名前空間の boot 確認
- Docker 関連ファイルの不在確認（P0-T4 開始前）

`scripts/verify-p0` で確認できない項目は、完了報告に実測結果を記載する。
