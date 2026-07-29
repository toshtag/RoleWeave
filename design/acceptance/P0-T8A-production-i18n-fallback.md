# P0-T8A 受け入れ条件 — production の i18n フォールバック無効化

この文書は P0-T8A の受け入れ条件の正本とする。
P0-T8A の実装者は、着手前にこの文書を読み、完了報告でここの各項目に対する結果を示す。

## 目的

すべての実行環境で、欠落した英語翻訳が日本語へ暗黙にフォールバックしない状態を保証する。

今回決めるのはフォールバック方針だけとする。
production で翻訳欠落を例外化するか、エラー監視へ送るか、
どのように利用者へ表示するかは今回決めない。

## 変更前の問題

P0-T8 は `config/application.rb` で全環境向けにフォールバックを無効化した。

```ruby
config.i18n.fallbacks = false
```

しかし `config/environments/production.rb` には Rails 生成時の設定が残っており、
環境設定はアプリケーション共通設定より後に読み込まれるため、これを上書きしていた。

```ruby
config.i18n.fallbacks = true
```

その結果、production だけがフォールバック有効のまま残った。

```text
RAILS_ENV=production
I18n.backend.store_translations(:ja, key => "日本語だけの文言")
I18n.t(key, locale: :en, raise: true)
=> "日本語だけの文言"
```

これは次の契約と矛盾する。

- `design/acceptance/P0-T8-i18n-bootstrap.md` — 日英同時実装の原則をフォールバックで隠さない
- `docs/development/language-policy.md` — 日本語と英語を初期段階から同等に扱う
- `design/rules/cross-cutting-quality.md` — 利用者向け文字列は同じフェーズで日英を実装する

P0-T8 の受け入れ条件は production を意図的に除外していた。
つまり受け入れ条件そのものが、目的を満たさないように弱められていた。
本タスクでその不整合を解消する。

## 実装要件

### 単一の正本

i18n フォールバックの設定は `config/application.rb` の次の行だけを正本とする。

```ruby
config.i18n.fallbacks = false
```

### production の上書き削除

`config/environments/production.rb` から Rails 生成時の次の記述を削除する。

```ruby
# Enable locale fallbacks for I18n (makes lookups for any locale fall back to
# the I18n.default_locale when a translation cannot be found).
config.i18n.fallbacks = true
```

`config.i18n.fallbacks = false` を production へ重複して追加しない。
同じ設定を 2 箇所へ書くと、次に片方だけ変更されたときに矛盾が生まれる。

### production の翻訳欠落

`config.i18n.raise_on_missing_translations` の production 設定は今回変更しない。

production で翻訳欠落をどう扱うか（例外化するか、監視へ送るか、
利用者へどう見せるか）は、運用方針とエラー監視が整うフェーズで決定する。

フォールバックの無効化はこの判断を待たない。
フォールバックは「欠落をどう扱うか」ではなく「欠落を欠落として観測できるか」の問題であり、
有効なままでは欠落そのものが観測できない。

## 検証の配置

P0-T8A の検証は `scripts/verify-p0` の P0-T8 系検証へ追加し、
P0-T8A の進捗イベントが記録された時点で有効にする。

`test/configuration/i18n_configuration_test.rb` は test 環境で実行されるため、
production の設定を検証できない。production の検証は
`RAILS_ENV=production` で実際に boot して行う。

## 正の検証

### 静的検証

- `config/environments/production.rb` が `config.i18n.fallbacks` を有効化していない

### 実測検証

`RAILS_ENV=production` で boot し、日本語だけに存在する翻訳を登録したうえで、
英語からの解決が `I18n::MissingTranslationData` になることを確認する。

```text
I18n.backend.store_translations(:ja, key => "日本語だけの文言")
I18n.t(key, locale: :en, raise: true)
=> I18n::MissingTranslationData
```

バックエンドの祖先クラス名だけで判定しない。
実際に日本語だけの翻訳を登録し、英語から解決されない振る舞いを確認する。

production boot にはデータベース接続を必要としない。
到達不能な `DATABASE_URL` を与え、boot 中に不用意な接続が起きていないことも併せて検出する。

### コマンド

- `docker compose run --rm app bin/verify` が exit 0 で終了する
- `bin/verify --full` が exit 0 で終了する
- `npm run pact:validate` と `npm run pact:lint` が exit 0 で終了する
- 最終 HEAD に対応する GitHub Actions の run が success で終了する

## 負の検証

`config/environments/production.rb` へ `config.i18n.fallbacks = true` を戻した場合、
次のいずれもが非 0 で拒否されること。

```text
静的検査
production boot 後の振る舞い検査
```

恒久ファイルを未復元の状態で残さない。

あわせて次を確認する。

- test 環境の既存 i18n 契約が引き続き成功する
- P0-T1 から P0-T8 までの累積検証を弱体化していない

## 非目標

次は P0-T8A で実装しない。

```text
production での翻訳欠落の例外化
production でのエラー監視
言語切替 UI
locale 付き URL
Accept-Language によるブラウザー言語判定
Cookie・セッションへの言語保存
画面の追加
JavaScript 側の翻訳
新しい依存関係の追加
セキュリティと依存関係検査（P0-T9）
Foundation 完了検証（P0-T10）
```

## 変更禁止範囲

次のファイルを P0-T8A で変更しない。

```text
config/application.rb
config/environments/development.rb
config/environments/test.rb
config/locales/**
config/routes.rb
app/**
test/**
Gemfile / Gemfile.lock
package.json / package-lock.json
compose.yaml
Dockerfile
.github/**
bin/**
scripts/verify-p0-docker
docs/**
P1 以降の phase 契約
```

P0-T8 の進捗イベント（`.code-pact/state/events/**`）を変更・削除しない。
P0-T8 はすでに finalize 済みであり、履歴を改変せずに是正タスクを積み上げる。

`design/` は、`task start` 前の契約コミットと `task finalize --write` による正規更新を除いて変更しない。

## 実装時の注意

- `design/phases/*.yaml` は Code Pact の保護パスであるため、P0-T8A の `writes` へ宣言しない
- `code-pact verify --task` は done イベントを前提とするため、`task complete` の後に実行する
- finalize は dry-run と `--write` の両方で `--audit-strict` を指定し、
  `--base-ref` には P0-T8A の契約コミットを指定する
- `write_audit` の不整合をダミー差分で解消しない。原因を報告して停止する
- 実行していない検証を成功として報告しない

### 実行後の追記

上の `code-pact verify --task` に関する記述は不完全だった。

P0-T8A の実行中、`task complete` 直後の `code-pact verify` は、
フェーズ YAML の status が `done` になっていないため `task_status` で失敗した。
`verify` は done イベントだけでなくフェーズ YAML の status も確認するため、
`task finalize --write` より前には成功しない。

Code Pact 2.8.0 における RoleWeave の正規順序は次のとおりである。

```text
task complete → task finalize --write → code-pact verify
```

この文書の実行時記述と、`docs/development/code-pact.md` および
`design/rules/code-pact-execution.md` との不整合は P0-T8B で是正した。
詳細は `design/acceptance/P0-T8B-i18n-and-code-pact-contract.md` を参照する。

### 検証の不足

P0-T8A で追加した静的検査は `config/environments/production.rb` の
`config.i18n.fallbacks = true` だけを拒否する。
production へ重複した `false` を追加しても、development や test へ再定義を追加しても通過する。

「正本は `config/application.rb` の 1 件だけ」という上の要件は、
P0-T8A の時点では回帰検査で固定できていなかった。P0-T8B で構造的な検査を追加した。
