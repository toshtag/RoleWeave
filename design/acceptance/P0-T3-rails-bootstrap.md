# P0-T3 受け入れ条件 — Rails アプリケーションの生成

この文書は P0-T3 の受け入れ条件の正本とする。
P0-T3 の実装者は、着手前にこの文書を読み、完了報告でここの各項目に対する結果を示す。

## 目的

既存の OSS 文書と Code Pact 制御面を保持しながら、リポジトリ直下へ最小の Rails アプリケーションを生成する。

## 固定バージョン

```text
Ruby:              4.0.6
Rails:             8.1.3
Database adapter:  PostgreSQL
JavaScript:        importmap
Test framework:    Minitest
```

開発ランタイムは Node.js `24.18.0`（`.node-version`）を前提とする。

別バージョンを自動選択しない。
実行環境に Ruby 4.0.6 または Rails 8.1.3 がない場合は、別バージョンで生成せず、環境を整備してから実行する。

`.ruby-version` と `.node-version` のファイル内容だけでは不十分である。
実際に動いているランタイムが一致していることを確認する。

## 生成方針

- 既存リポジトリへ `rails new . --force` を直接実行しない
- リポジトリ外の一時ディレクトリへ Rails アプリを生成する
- 生成物から許可されたファイルだけをリポジトリへコピーする
- 既存の README、LICENSE、`design/`、`docs/`、`.github/`、Node.js 設定を上書きしない
  - Rails は `README.md` を生成する。これはコピーしない
- アプリケーション設定名前空間は `RoleWeave` とする
- 業務モデルの親名前空間には `RoleWeave` を使わない
- React、Next.js、GraphQL、Redis、OpenSearch を追加しない

### 必須の generator オプション

最低限、次のすべてを使用する。

```text
--name=RoleWeave
--database=postgresql
--skip-git
--skip-docker
--skip-ci
--skip-kamal
--skip-thruster
--no-rc
```

`--no-rc` により、開発者個人の `~/.railsrc` や XDG 設定が生成結果へ混入しないようにする。
`--skip-ci` は `.github/workflows/` と `.github/dependabot.yml` の生成を止める。
`--skip-kamal` と `--skip-thruster` を明示しないと、Kamal・Thruster が Gemfile と生成ファイルへ入る。

次は使用しない。

```text
--minimal
--skip-hotwire
--skip-active-job
--skip-active-storage
--skip-action-mailer
--skip-test
--skip-solid
--devcontainer
```

着手前に、使用する Rails バージョンの `rails new --help` でオプションの実在を確認する。

## Git 管理ファイル

`--skip-git` は Git 初期化に加えて `.gitignore` と `.gitattributes` の生成も省略する。
そのため、生成後に手動で整備する。

### 保持する既存の ignore 設定

次の行を置換、削除、重複させない。

```text
/node_modules/
/.code-pact/locks/
/.code-pact/state/locks/
/.code-pact/cache/
/.local/
/.context/
```

`.gitignore` 全体を Rails 生成物で置き換える実装は成功扱いにしない。

### 追記する Rails 8.1.3 標準の ignore 設定

次の行をちょうど 1 件ずつ持たせる。

```text
/.bundle
/.env*
/log/*
!/log/.keep
/tmp/*
!/tmp/.keep
/tmp/pids/*
!/tmp/pids/
!/tmp/pids/.keep
/storage/*
!/storage/.keep
/tmp/storage/*
!/tmp/storage/
!/tmp/storage/.keep
/public/assets
/config/*.key
```

`.keep` の除外解除がないと、Rails が生成する `log/.keep`、`tmp/.keep`、`storage/.keep` などが
Git 管理対象にならず、維持すると宣言した標準生成物が失われる。
`/tmp/pids/` と `/tmp/storage/` はディレクトリ自体を再包含する。

`/config/*.key` は、Rails の credentials generator が `.gitignore` の存在時にのみ追記する。
`--skip-git` では `.gitignore` 自体が生成されないため追記されず、警告だけが出る。

### `.gitattributes`

Rails 標準の次の行を、ちょうど 1 件ずつ持たせる。

```text
db/schema.rb linguist-generated
vendor/* linguist-vendored
```

### 共通の要件

- 既存設定を全面置換しない
- 同じ行を重複させない（欠落と重複の両方を検証で拒否する）

## credentials

一時生成先の次のファイルはリポジトリへコピーしない。

```text
config/master.key
config/credentials.yml.enc
```

P0 では本番秘密情報管理を決定しない。
秘密鍵、API キー、実在する認証情報をコミットしない。

## 維持する Rails 標準生成物

- Hotwire、importmap
- Active Job、Active Storage、Action Mailer
- Minitest
- Solid Queue、Solid Cache、Solid Cable
- RuboCop（`.rubocop.yml`、`bin/rubocop`）
- Brakeman、bundler-audit
- Rails 標準の `bin/setup`
- Rails 標準の `bin/ci` と `config/ci.rb`
  （これらは GitHub Actions ではなく、Rails アプリケーション内のローカル検証入口である。
  `bin/verify` との関係は P0-T6 で確定する）
- Rails 標準の `script/`
- Rails 標準の `.keep` ファイル

Rails 標準の `.keep` ディレクトリは「将来用の独自ディレクトリ」に該当しない。
P0-T3 では独自の `app/services`、`app/domains`、`app/use_cases` などを追加しない。

## 含めない生成物

```text
Dockerfile
.dockerignore
bin/docker-entrypoint
compose.yaml
docker-compose.yml
.devcontainer/
.github/workflows/
.github/dependabot.yml
.kamal/
config/deploy.yml
bin/kamal
bin/thrust
Procfile.dev
```

`Procfile.dev` は importmap 構成では生成されないため、write scope にも含めていない。

## README

README 全体を書き換えない。
日本語版と英語版の「現在の状態」だけを、次の事実へ更新する。

- Rails アプリケーションの基盤は存在する
- 求人、応募、認証などの業務機能はまだ実装されていない
- 本番利用はまだ推奨しない

日本語版と英語版で事実を一致させる。

## 正の検証

- `.ruby-version` が `4.0.6`
- 実行中の `RUBY_VERSION` が `4.0.6`
- 実行中の `node --version` が `v24.18.0`
- `bundle exec rails --version` が `Rails 8.1.3`
- `Gemfile` に `pg` がある
- `config/database.yml` が PostgreSQL を使用する
- `config/application.rb` のアプリケーション名前空間が `RoleWeave`
- `.gitignore` が既存の Code Pact / Node.js 用設定を保持している
- `.gitignore` に Rails 用除外設定、`.keep` の除外解除、`/config/*.key` がある
- `.gitignore` と `.gitattributes` の必須行がいずれも重複していない
- `.gitattributes` がある
- `.rubocop.yml` がある
- `bundle check` が成功する
- PostgreSQL サーバーがない状態で boot と Zeitwerk 検査が成功する
- Rails 標準のテストディレクトリが存在する
- README の日本語版と英語版が現在状態と一致する
- 既存の Code Pact 検証が成功する

### PostgreSQL なしでの boot 検証

P0-T4 まで PostgreSQL を導入しないため、接続不能な `DATABASE_URL` を与えて実行する。

```bash
env RAILS_ENV=test DATABASE_URL=postgresql://127.0.0.1:1/roleweave_test PGCONNECT_TIMEOUT=1 \
  bundle exec rails zeitwerk:check
```

```bash
env RAILS_ENV=test DATABASE_URL=postgresql://127.0.0.1:1/roleweave_test PGCONNECT_TIMEOUT=1 \
  bundle exec rails runner 'abort "unexpected application namespace" unless Rails.application.class.module_parent_name == "RoleWeave"'
```

これにより、boot 中に不用意な DB 接続を発生させていないことを確認する。
失敗した場合、検証を削除または無効化しない。
どの initializer または設定が接続を発生させたかを調査する。

## 負の検証

- `README.md` と `README.en.md` は、「現在の状態」節以外を変更していない
- `LICENSE`、`design/`、`docs/`、`.github/`、`package.json`、`package-lock.json` を変更していない
  （受け入れ条件や設計文書を、実装の都合に合わせて変更しない）
- `config/master.key` がない
- `config/credentials.yml.enc` がない
- Docker 関連ファイル（`Dockerfile`、`.dockerignore`、`bin/docker-entrypoint`、
  `compose.yaml`、`docker-compose.yml`）がない
- `.devcontainer/` がない
- Kamal 関連ファイル（`.kamal/`、`config/deploy.yml`、`bin/kamal`）がない
- Thruster 関連ファイル（`bin/thrust`）がない
- `.github/workflows/` と `.github/dependabot.yml` がない
- `Procfile.dev` がない
- 個人の `.railsrc` 設定が生成結果へ混入していない
- Ruby と Rails の別バージョンを使用していない
- 旧システム由来の固有名詞がない
- React、Next.js、Redis、OpenSearch が追加されていない
- 将来用の独自空ディレクトリを作っていない
- 求人、応募、認証などの業務機能を実装していない

## 自動検証との対応

上記のうち機械的に確認できる項目は `scripts/verify-p0` に実装済みで、
P0-T3 の `started` イベントが記録された時点から自動的に有効になる。

- 実行中の Node.js が `24.18.0`、`package.json` の `engines.node` が `>=24.18.0 <25`（P0 全体で常時）
- 既存の Code Pact / Node.js 用 ignore 設定の保持（P0 全体で常時）
- Rails 実体の存在確認、`pg` gem、`adapter: postgresql`、`module RoleWeave`
- `.ruby-version` = `4.0.6`、実行中の `RUBY_VERSION` = `4.0.6`、
  `bundle exec rails --version` = `Rails 8.1.3`
- `.gitignore` の Rails 用除外設定、`.keep` の除外解除、`/config/*.key`、
  `.gitattributes`、`.rubocop.yml`
- `.gitignore` と `.gitattributes` の必須行の重複拒否
- `bundle check`、PostgreSQL なしでの `zeitwerk:check` と名前空間 boot 確認
- README の古い文言が残っていないこと
- Kamal / Thruster / devcontainer / master key / credentials の不在（P0 全体で常時）
- Docker 関連ファイルの不在（P0-T4 開始前）
- GitHub Actions 関連ファイルの不在（P0-T7 開始前）

`scripts/verify-p0` で確認できない項目は、完了報告に実測結果を記載する。

## 実装時の注意

- P0-T3 の finalize は `--audit-strict` で行う。
  宣言した write scope のうち、追跡ファイルが 1 件も生じないものがあると
  `TASK_WRITES_AUDIT_DECLARED_UNUSED` で失敗する。
  `log/**`、`tmp/**`、`storage/**`、`vendor/**` は Rails 標準の `.keep` ファイルが
  追跡対象になることを前提にしている。`--skip-keeps` を使わない。
