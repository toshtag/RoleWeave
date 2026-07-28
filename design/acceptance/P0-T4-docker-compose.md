# P0-T4 受け入れ条件 — PostgreSQL 対応 Docker Compose の追加

この文書は P0-T4 の受け入れ条件の正本とする。
P0-T4 の実装者は、着手前にこの文書を読み、完了報告でここの各項目に対する結果を示す。

## 目的

Rails アプリケーションと PostgreSQL を Docker Compose で起動できる、
再現可能なローカル開発基盤を構築する。

## 固定イメージ

```text
Application image: ruby:4.0.6-slim-bookworm
Node source image: node:24.18.0-bookworm-slim
Database image:    postgres:18.4-bookworm
```

```text
Ruby:       4.0.6
Rails:      8.1.3
Node.js:    24.18.0
PostgreSQL: 18.4
Code Pact:  2.8.0
```

メジャータグやフローティングタグを使用しない。
`ruby:4`、`ruby:4.0`、`node:24`、`node:lts`、`postgres:18`、`postgres:latest` はいずれも不可とする。

Debian の世代差による挙動差を避けるため、すべて Bookworm 系列で揃える。

イメージ digest は固定しない。
バージョンと OS 系列を固定したうえで、同一タグのセキュリティ再ビルドを取得できる状態を維持する。

## 対象サービス

Compose に定義するサービスは次の 2 つだけとする。

```text
app
db
```

worker 専用サービス、メール確認用サービス、オブジェクトストレージ、Redis、OpenSearch を追加しない。

## Dockerfile 要件

- 開発専用の build target を `development` とする
- Node.js は公式 Node イメージから必要部分だけを取得する
- Node イメージの `/usr/local` 全体をコピーしない
- Ruby の実行ファイルを Node イメージで上書きしない
- `apt-get update` と `apt-get install` を同じ `RUN` で実行する
- `--no-install-recommends` を使用する
- apt cache を削除する
- `bundle install` は lockfile を変更できない状態で実行する
- `npm install` ではなく `npm ci` を使用する
- assets precompile を実行しない
- production 用の環境変数を設定しない
- credentials を要求しない
- `db:prepare` を Dockerfile で実行しない
- rootless 化と本番用マルチステージは P0-T4 では扱わない

## Compose 要件

- トップレベルの `version` キーを使用しない
- サービスは `app` と `db` だけとする
- `db` はホストへポートを公開しない
- `app` の公開ポートは `APP_PORT` で上書きできる
- `app` の公開ポートは IPv4 ループバック `127.0.0.1` だけへバインドする
- ホスト IP を省略しない。省略すると Docker はすべてのホストインターフェースへ公開する
- `0.0.0.0`、`::`、その他の LAN 向けアドレスへ公開しない
- 既定では Docker ホスト自身からだけアクセスできる構成とする
- `app` は `db` の healthcheck 成功後に起動する（`condition: service_healthy`）
- bind mount と依存キャッシュ用 named volume を分離する
- named volume は `bundle`、`node_modules`、`postgres_data` とする
- anonymous volume を作らない
- `restart` ポリシーを設定しない
- `container_name` を設定しない
- `platform` を固定しない
- Compose Watch と profile を追加しない

## PostgreSQL 18 のボリューム位置

PostgreSQL 18 では永続データのマウント先が `/var/lib/postgresql` へ変更されている。

```text
volume target: /var/lib/postgresql
```

PostgreSQL 17 以前の `/var/lib/postgresql/data` を使用しない。
旧来の位置をマウントすると、永続化されているように見えて実際には失われる構成になり得る。

## DB 接続環境変数

`config/database.yml` の `default` は次の環境変数を参照する。

```text
DATABASE_HOST
DATABASE_PORT
DATABASE_USERNAME
DATABASE_PASSWORD
```

- `development` は `role_weave_development`
- `test` は `role_weave_test`
- `production` 設定を P0-T4 で設計し直さない
- `DATABASE_URL` へ一本化しない
- 環境変数がない場合はローカル Unix socket の利用を妨げない
- パスワードを `config/database.yml` へ直接記載しない
- Docker 固有のホスト名 `db` を設定ファイルへ直接記載しない

Compose に記載する `roleweave` / `roleweave` は開発用の固定資格情報である。
本番環境へ使用できる設計として扱わない。
`POSTGRES_HOST_AUTH_METHOD=trust` を使用しない。

## 永続化要件

`db` コンテナを削除して再作成しても、`postgres_data` の内容が失われないこと。

## healthcheck

- `db` は `pg_isready` で準備完了を判定する
- `app` は `bin/docker-healthcheck` で `/up` の応答を判定する
- healthcheck から業務ログや例外詳細を出力しない

## Docker 用スクリプト

`bin/docker-entrypoint` の要件。

- 依存インストールを行わない
- `db:prepare` を行わない
- PostgreSQL 待機ループを独自実装しない（Compose の `service_healthy` に委ねる）
- stale な Puma PID だけを削除する
- 最後に `exec` する

`bin/docker-healthcheck` は Ruby 標準ライブラリだけで `/up` へ HTTP リクエストする。

いずれも実行権限を持たせる。

## build context

`.dockerignore` の要件。

- 秘密鍵を build context へ含めない
- ローカルキャッシュを含めない
- `design/`、`docs/`、`scripts/` は除外しない
- Code Pact をコンテナ内でも実行可能な build context を維持する
- 同じ行を重複させない

## 正の検証

Docker 固有の検証は `scripts/verify-p0-docker` へ実装し、
`scripts/verify-p0` から P0-T4 の進捗イベントを条件に呼び出す。

### 静的検証

- Docker daemon へ接続できる
- `docker compose config --quiet` が成功する
- サービスが `app` と `db` だけである
- `app` の build target が `development` である
- DB イメージが `postgres:18.4-bookworm` である
- `db` にホスト公開ポートがない
- `app` の port 定義がちょうど 1 件である
- `app` の port の `host_ip` が `127.0.0.1` である
- `app` の port の container target が 3000、protocol が tcp である
- PostgreSQL の volume target が `/var/lib/postgresql` である
- `/var/lib/postgresql/data` を使用していない
- `POSTGRES_HOST_AUTH_METHOD` がない
- `app` が `db` の `service_healthy` へ依存している
- `app` と `db` の双方に healthcheck がある
- named volume が `bundle`、`node_modules`、`postgres_data` である
- Dockerfile の Ruby・Node.js タグが固定されている
- `.dockerignore` の必須行がそれぞれちょうど 1 件である
- Docker 用スクリプトが実行可能である
- `config/database.yml` が 4 つの DB 環境変数を参照する
- `Gemfile`、lockfile、package ファイルに差分がない

Compose の正規化結果は `docker compose config --format json` から取得し、
Ruby の `JSON` で構造を検証する。
YAML のインデントに依存した grep だけで判定しない。

### 動的検証

- `docker compose build app` が成功する
- コンテナ内の `RUBY_VERSION` が `4.0.6`
- コンテナ内の `node --version` が `v24.18.0`
- コンテナ内の `bundle exec rails --version` が `Rails 8.1.3`
- コンテナ内で `bundle check` が成功する
- コンテナ内で `npm ls --depth=0` が成功する
- `db` が healthy になる
- `SHOW server_version_num` が `180004`
- `development` の `db:prepare` が成功する
- `test` の `db:prepare` が成功する
- Rails 経由でも `server_version_num` が `180004`
- `db` コンテナの削除・再作成後もデータが残る
- `app` が healthy になる
- `docker compose port app 3000` が `127.0.0.1:<検証用ポート>` を返す
- ホストから `127.0.0.1:<検証用ポート>/up` が 200 を返す

### 検証環境の隔離

- 検証専用の Compose project name を使用する
- ホストポートは実行時に空きポートを取得して割り当てる
- 成功・失敗にかかわらず、`trap` で検証専用環境だけを削除する
- 通常の開発用 project や volume へ `down --volumes` を実行しない

## 負の検証

次の変更を一時的に加えた場合、`scripts/verify-p0-docker` が非 0 で終了すること。

- PostgreSQL イメージを `postgres:18` へ変更する
- PostgreSQL の volume target を `/var/lib/postgresql/data` へ変更する
- `db` へ `POSTGRES_HOST_AUTH_METHOD: trust` を追加する
- `db` へホスト公開ポート `5432:5432` を追加する
- `app` の `depends_on` を削除する
- `app` の公開ポートからホスト IP `127.0.0.1:` を削除する
- `app` の公開ポートのホスト IP を `0.0.0.0` へ変更する

`bin/docker-healthcheck` を `exit 1` へ変更した場合、
隔離 project での `docker compose up -d --wait app` が非 0 で終了すること。

一時変更はすべて復元し、一時的な Docker resource を残さない。

## 非目標

次は P0-T4 で実装しない。

```text
bin/setup の改修
bin/verify の新設
GitHub Actions
Dev Container
Compose Watch
Redis
OpenSearch
worker 専用サービス
メール確認用サービス
オブジェクトストレージ
本番用 Docker イメージ
Kamal
Thruster
デプロイ設定
業務機能
README のセットアップ手順
.env / .env.example
PostgreSQL のホストポート公開
```

P0-T5 以降の処理を先回りしない。
依存インストールと DB 準備の冪等化は P0-T5 で扱う。

## 変更禁止範囲

次のファイルを P0-T4 で変更しない。

```text
Gemfile
Gemfile.lock
package.json
package-lock.json
bin/setup
bin/verify
README.md
README.en.md
LICENSE
.github/**
```

現在の lockfile には Linux プラットフォームが登録済みである。
コンテナ内の実測で不足が確認されない限り更新しない。
不足が確認された場合も、このタスク中に契約を変更せず、原因を報告して停止する。

`design/` と `docs/` は、`task start` 前の契約コミットを除いて変更しない。

## 実装時の注意

- `design/phases/*.yaml` は Code Pact の保護パスであるため、P0-T4 の `writes` へ宣言しない。
  契約の詳細化はこの文書と同じコミットで済ませ、`task start` 前に作業ツリーを clean にする
- `task complete` が P0 の verification command を実行するため、
  先に単独の `code-pact verify` を要求しない
- finalize は dry-run と `--write` の両方で `--audit-strict` を指定する
- `write_audit` の不整合をダミー差分で解消しない。原因を報告して停止する
