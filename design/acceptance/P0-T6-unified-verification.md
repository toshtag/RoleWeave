# P0-T6 受け入れ条件 — 統一検証コマンドの追加

この文書は P0-T6 の受け入れ条件の正本とする。
P0-T6 の実装者は、着手前にこの文書を読み、完了報告でここの各項目に対する結果を示す。

## 目的

開発者、AI Agent、将来の CI が共通して使用する検証の公開入口を `bin/verify` へ一本化する。

- コンテナ内で、アプリケーションと Code Pact 制御面の標準検証を実行できる
- ホストから、Docker 基盤とセットアップ冪等性を含む P0 完全検証を実行できる
- Rails 標準の `bin/ci` は互換入口として維持するが、独立した検証定義を持たせない

検証の定義を複数箇所へ分散させない。
「何を検証するか」の正本を `bin/verify` だけとする。

## 正規コマンド

```bash
docker compose run --rm app bin/verify
```

```bash
bin/verify --full
```

利用者と CI は、この 2 つだけを使用する。

## 標準モード

`bin/verify` は引数なしで次を順番に実行する。

```text
1. Ruby 依存関係の充足確認
2. Node.js 依存関係の充足確認
3. Code Pact validate
4. Code Pact strict plan lint
5. Ruby style 検査
6. test データベースの準備
7. Zeitwerk 検査
8. Rails test
```

```bash
bundle check
npm ls --depth=0
npm run pact:validate
npm run pact:lint
bin/rubocop
env RAILS_ENV=test bin/rails db:prepare
env RAILS_ENV=test bin/rails zeitwerk:check
env RAILS_ENV=test bin/rails test
```

Rails test を最後の検証とする。
静的な契約違反を、時間のかかるテスト実行より前に失敗させる。

## 完全モード

`bin/verify --full` は `scripts/verify-p0` を実行する。
包含関係は次のとおりとする。

```text
bin/verify --full
└── scripts/verify-p0
    └── scripts/verify-p0-docker
        └── docker compose run --rm app bin/verify
```

完全モードは、標準モードをコンテナ内で実測する。
標準検証の定義を Docker 検証側へ複製しない。

`bin/verify --full` から再び `bin/verify --full` を呼ぶ再帰構造を作らない。

## 責務分離

- 標準モードは Docker を起動しない
- 完全モードだけが Docker 基盤検証を行う
- セットアップと検証を混在させない。標準モードは `bin/setup` を呼ばない
- 依存関係をインストールしない。充足していない場合は失敗させる
- lockfile を更新しない
- development データベースを変更しない。準備するのは test だけとする
- サーバーを起動せず、常駐処理を行わない
- security audit は P0-T9 まで必須化しない
- `scripts/verify-p0` と `scripts/verify-p0-docker` は内部実装であり、公開入口ではない

## 引数

受け付ける形式は次だけとする。

```text
bin/verify
bin/verify --full
```

未知の引数は黙って無視せず、非 0 で終了する。

```bash
bin/verify --quick
bin/verify --full extra
bin/verify unexpected-argument
```

## bin/ci

Rails 標準の `bin/ci` は `bin/verify --full` へ委譲するだけの互換ラッパーとする。

- 独自の検証コマンド一覧を持たない
- `ActiveSupport::ContinuousIntegration` を使用しない
- 引数の検査を `bin/verify` へ委譲する
- 実行権限を維持する

`config/ci.rb` は削除する。

- `bin/verify` と別のコマンド一覧を持つ二重正本になる
- 現在は拒否される `bin/setup --skip-server` を実行するため、そのままでは動作しない
- P0-T9 で扱うセキュリティ検査を先回りしている

空の代替ファイルを残さない。

## 実装要件

- コマンドは引数配列で実行する
- `eval` を使用しない
- `bash -c` を使用しない
- shell 文字列を組み立てない
- 一つでも失敗した時点で非 0 で終了する
- コメントと独自出力は日本語で書く
- 実行権限を維持する

## bootstrap 入口

Code Pact は `task start` 時にフェーズの `verification.commands` をロックする。
P0 の検証コマンドを `bin/verify --full` へ変更するには、start 前に `bin/verify` が実在している必要がある。

この順序制約に対応するため、契約コミットでは bootstrap 版の `bin/verify` を追加する。

- 完全モードは `scripts/verify-p0` へ委譲する
- 標準モードは未実装として非 0 で終了する
- P0-T6 開始後に最終実装へ置き換える
- 最終コミットへ bootstrap 用の文言を残さない

## 正の検証

P0-T6 の静的検証は `scripts/verify-p0` へ実装し、
P0-T6 の進捗イベントが記録された時点で有効にする。
Docker 検証より前へ置き、契約違反を build より先に失敗させる。

### 静的検証

- `bin/verify` と `bin/ci` が実行可能である
- `bash -n bin/verify` と `bash -n bin/ci` が成功する
- `config/ci.rb` が存在しない
- P0 の `verification.commands` が `["bin/verify --full"]` と完全に一致する
- `bin/verify` が標準検証の 8 コマンドをすべて含む
- `bin/verify` が Docker を直接呼び出さない
- `bin/verify` が `bin/setup` を呼ばない
- `bin/verify` が bundler-audit / importmap audit / Brakeman を含まない
- `bin/ci` が `bin/verify --full` へ委譲する

フェーズ定義の検査は YAML として解析する。
Code Pact の serializer による表記の変化に依存しないよう、インデント前提の grep を使わない。

### 動的検証

- `docker compose run --rm app bin/verify` が exit 0 で終了する
- `bin/verify --full` が exit 0 で終了する
- Rails test が実行される
- RuboCop が実行される
- Code Pact validate と strict plan lint が実行される
- test データベースが使用される
- development データベースが変更されない
- 完全モードで既存の P0 検証がすべて成功する
- one-off の app コンテナが残らない
- lockfile に差分が出ない

## 負の検証

次の変更を一時的に加えた場合、`bin/verify --full` が非 0 で終了すること。

```text
bin/verify から Rails test を削除する
bin/verify から bin/rubocop を削除する
bin/verify から npm run pact:lint を削除する
RAILS_ENV=test を RAILS_ENV=development へ変更する
P0 の verification.commands を scripts/verify-p0 へ戻す
config/ci.rb を復元する
bin/verify へ docker の直接呼び出しを追加する
bin/ci へ独立した検証コマンド一覧を追加する
```

次のコマンドが非 0 で終了すること。

```bash
bin/verify --quick
bin/verify --full extra
bin/verify unexpected-argument
bin/ci unexpected-argument
```

一時変更はすべて復元し、一時的な Docker resource を残さない。

## 既存検証の維持

P0-T6 を理由に、P0-T3 / P0-T4 / P0-T5 で確立した検証を削除・弱体化しない。

```text
Node.js / Ruby / Rails の実行時バージョン
Code Pact validate と strict plan lint
Docker / Compose の静的契約
PostgreSQL 18.4（server_version_num = 180004）
bin/setup の静的検証と冪等性の動的検証
DB の永続化
app の healthcheck とループバック限定ポート
/up が 200 を返す
依存 lockfile の無変更
cleanup（trap）
```

`scripts/verify-p0-docker` の test DB 直接準備だけを、P0-T6 のイベントがある場合に
`docker compose run --rm app bin/verify` へ置き換える。
イベントがない過去 tree では既存処理を維持する。

## 非目標

次は P0-T6 で実装しない。

```text
GitHub Actions（P0-T7）
Brakeman の必須検証化（P0-T9）
bundler-audit の必須検証化（P0-T9）
importmap audit の必須検証化（P0-T9）
system test
JavaScript / CSS の追加 Linter
並列テスト
changed-files による対象限定検証
キャッシュ最適化
Docker build の高速化
カバレッジ計測
テストの追加
README のコマンド説明
依存関係の更新
業務機能
```

## 変更禁止範囲

次のファイルを P0-T6 で変更しない。

```text
bin/setup
Dockerfile
compose.yaml
.dockerignore
config/database.yml
Gemfile / Gemfile.lock
package.json / package-lock.json
README.md / README.en.md
docs/**
.github/**
```

`design/` は、`task start` 前の契約コミットを除いて変更しない。

## 実装時の注意

- `design/phases/*.yaml` は Code Pact の保護パスであるため、P0-T6 の `writes` へ宣言しない。
  契約の詳細化とフェーズ検証コマンドの変更は契約コミットで済ませ、
  `task start` 前に作業ツリーを clean にする
- `task complete` が P0 の verification command として `bin/verify --full` を実行するため、
  先に単独の `code-pact verify` を要求しない
- finalize は dry-run と `--write` の両方で `--audit-strict` を指定する
- `write_audit` の不整合をダミー差分で解消しない。原因を報告して停止する
