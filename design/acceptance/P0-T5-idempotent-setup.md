# P0-T5 受け入れ条件 — 冪等なセットアップコマンドの追加

この文書は P0-T5 の受け入れ条件の正本とする。
P0-T5 の実装者は、着手前にこの文書を読み、完了報告でここの各項目に対する結果を示す。

## 目的

新規の Docker 環境を、1 つの「終了する」コマンドで開発可能な状態へ収束させる。

セットアップと開発サーバーの起動を分離する。
サーバー起動は `docker compose up` の責務とし、セットアップは責務に含めない。

## 正規コマンド

```bash
docker compose run --rm app bin/setup
```

`docker compose run --rm` は一時コンテナを終了時に削除する。
`bin/setup` がプロセスを置き換えて常駐すると、このコマンドは終了しない。

## セットアップ内容

`bin/setup` は、引数なしで次を順番に行う。

```text
1. Ruby 依存関係の確認
2. 不足時だけ、lockfile を変更できない状態で bundle install
3. npm ci による Node.js 依存関係の再現
4. bin/rails db:prepare
5. Rails の古い log・tmp の整理
6. exit 0 で終了
```

`npm ci` は lockfile に基づくクリーンインストールであり、依存定義を書き換えない。
`npm install` は解決結果によって `package-lock.json` を更新し得るため使用しない。

## 冪等性

同じ Compose project と同じ named volume に対して 2 回実行し、次が一致すること。

```text
Git 作業ツリーの状態
Gemfile と Gemfile.lock
package.json と package-lock.json
DB の public schema
schema migration の状態
setup 前に存在した検証用データ
インストール済み依存関係の整合性
```

「2 回目に何も処理しないこと」を冪等性としない。
「2 回目も同じ正しい状態へ収束し、破壊的な差分を残さないこと」を冪等性とする。

## 非破壊性

- `db:reset` を実行しない
- 既存の DB テーブルや行を削除しない
- seed を毎回強制実行しない
- lockfile を更新しない
- 追跡対象ファイルを生成・変更しない
- 開発サーバーを起動しない

## 引数

- 引数なしだけを受け付ける
- 未知の引数は非 0 で終了する
- `--reset` と `--skip-server` は受け付けない
- 引数の検査は DB 処理より前に行う

`--reset` のような破壊的操作が必要な場合は、利用者が Rails の DB コマンドを明示的に実行する。
破壊的操作を `bin/setup` の隠れたオプションにしない。

## 実装要件

- Ruby の配列形式でコマンドを実行し、ユーザー入力を shell 文字列へ連結しない
- `bundle check` が失敗した場合だけ `bundle install` を実行する
- `bundle install` は `BUNDLE_FROZEN=true` の下で実行する
- `exec` を使用しない
- `bin/dev` と `rails server` を呼ばない
- コメントと独自出力は日本語で書く
- 実行権限を維持する
- `APP_ROOT` の外側のファイルを操作しない

## 正の検証

Docker 固有の検証は `scripts/verify-p0-docker` へ実装し、
P0-T5 の進捗イベントが記録された時点で有効にする。

### 静的検証

- `bin/setup` が実行可能である
- `ruby -c bin/setup` が成功する
- `BUNDLE_FROZEN` を使用している
- `npm ci` を使用している
- `bin/rails db:prepare` を使用している
- `db:reset` を含まない
- `bin/dev` を含まない
- プロセス置換の `exec` を含まない
- `npm install` を含まない

### 動的検証

- 検証専用の空の Compose project で正規コマンドが exit 0 で終了する
- `db` サービスを事前に起動しなくても正規コマンドが成功する
- 空にした `bundle` と `node_modules` の named volume を復旧できる
- 2 回目の実行も exit 0 で終了する
- 2 回の DB 状態（public tables / schema migrations / metadata / 検証用行）が一致する
- setup 前に投入した検証用行が保持される
- `bundle check` が成功する
- `npm ls --depth=0` が成功する
- コマンド終了後に開発サーバーが起動していない
- one-off の app コンテナが残らない
- 実行前後で `git status --porcelain` の結果が一致する

## 負の検証

次の変更を一時的に加えた場合、`scripts/verify-p0-docker` が非 0 で終了すること。

- `npm ci` を `npm install` へ変更する
- `db:prepare` を削除する
- `db:reset` を追加する
- `exec` または `bin/dev` を追加する

次のコマンドが非 0 で終了すること。

```bash
docker compose run --rm app bin/setup --reset
docker compose run --rm app bin/setup --skip-server
docker compose run --rm app bin/setup unexpected-argument
```

`--reset` の拒否後も、DB のテーブルが破壊されていないこと。
2 回目の実行で検証用データが消えた場合、lockfile に差分が発生した場合はいずれも失敗とする。

一時変更はすべて復元し、一時的な Docker resource を残さない。

## 検証環境の隔離

- P0-T4 の検証で使う隔離 Compose project と空きポートをそのまま再利用する
- 依存 volume を空にする操作は、検証専用の named volume だけを対象にする
- ホストの `node_modules` を削除しない
- 通常の開発用 project や volume へ影響を与えない
- 別のイメージ build を重ねない

## 既存検証の維持

P0-T5 を理由に、P0-T4 で確立した次の検証を削除・弱体化しない。

```text
隔離 Compose project と空きポート取得
cleanup（trap）
compose build app
Ruby / Node.js / Rails のバージョン
PostgreSQL 18.4（server_version_num = 180004）
test DB の db:prepare
DB の永続化
app の healthcheck とループバック限定ポート
/up が 200 を返す
依存 lockfile の無変更
```

development DB に対する既存の直接 `db:prepare` は、P0-T5 のイベントがある場合だけ
`bin/setup` の検証へ置き換える。イベントがない過去 tree では既存処理を維持する。

## 非目標

次は P0-T5 で実装しない。

```text
bin/verify
GitHub Actions
README のセットアップ手順
Dev Container
Compose Watch
.env / .env.example
seed データ
業務モデル
認証
求人・応募機能
PostgreSQL / Docker / Gem / npm パッケージの更新
Docker Compose サービスの追加
DB 待機ループ
セットアップの並行実行制御
ホスト OS 別のセットアップ分岐
本番環境用セットアップ
setup 終了後のサーバー自動起動
test データベースの準備
Docker イメージの build 方針変更
macOS / Linux のホスト直接実行保証
```

## 変更禁止範囲

次のファイルを P0-T5 で変更しない。

```text
Gemfile
Gemfile.lock
package.json
package-lock.json
compose.yaml
Dockerfile
.dockerignore
bin/docker-entrypoint
bin/docker-healthcheck
config/database.yml
db/seeds.rb
scripts/verify-p0
README.md
README.en.md
LICENSE
.github/**
```

`design/` と `docs/` は、`task start` 前の契約コミットを除いて変更しない。

## 実装時の注意

- `design/phases/*.yaml` は Code Pact の保護パスであるため、P0-T5 の `writes` へ宣言しない。
  契約の詳細化はこの文書と同じコミットで済ませ、`task start` 前に作業ツリーを clean にする
- `task complete` が P0 の verification command を実行するため、
  先に単独の `code-pact verify` を要求しない
- finalize は dry-run と `--write` の両方で `--audit-strict` を指定する
- `write_audit` の不整合をダミー差分で解消しない。原因を報告して停止する
