# P0-T8E 受け入れ条件 — i18n 検証器の単純化と全環境の実動作固定

この文書は P0-T8E の受け入れ条件の正本とする。
P0-T8E の実装者は、着手前にこの文書を読み、完了報告でここの各項目に対する結果を示す。

## 目的

次の状態を、理解しやすく保守可能な検証で保証する。

- i18n フォールバックの正本は `config/application.rb` の 1 行である
- 正本は `config.i18n.fallbacks = false` である
- `config/**/*.rb` の他の場所に `fallbacks` を含むコードを置かない
- development で英語の欠落が日本語へフォールバックしない
- test で英語の欠落が日本語へフォールバックしない
- production で英語の欠落が日本語へフォールバックしない

あわせて、検証器が Ruby 全体を静的解析できるという主張をやめる。
動作保証を静的解析だけへ依存させない。

## 変更前の問題

P0-T8B から P0-T8D まで、Ruby の代入構文を個別に列挙して補修してきた。
その結果、i18n の 1 設定を静的に証明するためだけに
約 350 行の独自 Ruby 解析器を抱える状態になった。

それでも次はすべて通過した。development で実際に boot して確認したところ、
5 経路すべてがフォールバックを有効化した。

```ruby
config.i18n["fallbacks"] = true
config.i18n.merge!(fallbacks: true)
config.i18n.public_send(:"fallbacks=", true)
config.i18n.public_send("fall" + "backs=", true)
```

```ruby
# config/initializers/i18n_override.rb
Rails.application.config.i18n.fallbacks = true
```

`config.i18n` は `ActiveSupport::OrderedOptions` であり `Hash` を継承する。
`[]=` はキーをシンボル化し、setter 形式のメソッド呼び出しも `[]=` へ変換される。
field 代入ノードだけを見ても、設定変更経路は網羅できない。

Rails の I18n 初期化はアプリケーション initializer より後に実行されるため、
`config/initializers/**/*.rb` も上書き可能な範囲である。

一方で、無関係な `config.other.fallbacks = false` は未分類参照として拒否した。
過小検出と過剰検出を同時に持つ状態だった。

構文を追加し続ける方針そのものに限界がある。
1 設定のために汎用 Ruby 静的解析器を維持しない。

## 方針

### 撤去するもの

P0-T8B / P0-T8C / P0-T8D で追加した独自解析器を撤去する。

```text
Ripper.sexp の再帰的 AST 走査
:assign / :opassign / :massign の個別解析
receiver chain 解析
receiver と値の括弧正規化
boolean literal 解析
代入 target 位置の収集
未分類 identifier との位置照合
AST スキャナー用 synthetic probe
AST スキャナーの退行変異テスト
```

`scripts/verify-p0` には、現在守る契約と検証理由だけを書く。
経緯の説明を何十行も残さない。履歴は受け入れ条件文書へ置く。

### 採用するもの

1. 全 `config/**/*.rb` を対象とする限定的なソース規約
2. development / test / production の実際の Rails boot 検査

静的規約は「うっかり書いてしまう記述」を止める。
実動作保証は boot probe が担う。役割を分離する。

## ソース規約

### 対象

```text
config/**/*.rb
```

対象を固定のファイル一覧へ限定しない。

### 検出

各ファイルを `Ripper.sexp` で解析し、`nil` なら構文解析失敗として失敗する。
構文木の意味解析は行わない。

`Ripper.lex` のトークンを走査し、コメントと埋め込みドキュメントを除いたうえで、
トークン内容に `fallbacks` を含むものを収集する。

文字列、symbol、label、識別子をすべて対象にするため、少なくとも次を検出する。

```ruby
config.i18n.fallbacks = false
config.i18n["fallbacks"] = true
config.i18n[:fallbacks] = true
config.i18n.merge!(fallbacks: true)
config.i18n.public_send(:"fallbacks=", true)
config.other.fallbacks = false
```

### 許可条件

検出結果がちょうど 1 件であり、その位置を含むソース行が
インデントを除いて次と一致すること。

```ruby
config.i18n.fallbacks = false
```

同じ行の後方へ別の処理を置くことは許可しない。
コメント行は canonical として数えない。

```text
ファイル: config/application.rb
記述:     config.i18n.fallbacks = false
件数:     1
```

### コメント

コメント内の `fallbacks` は許可する。

```ruby
# config.i18n.fallbacks = true
```

### 無関係な fallbacks

`config/**/*.rb` では、無関係な設定を含めて `fallbacks` という
コード上の語を使用しないという保守規約に統一する。

したがって次も拒否する。

```ruby
config.other.fallbacks = false
```

これは P0-T8D の受け入れ条件が「許可する」としていた記述の訂正である。
コードの意味を解析して「i18n の fallbacks かどうか」を判定しようとした結果が
過小検出と過剰検出の同居だった。判定をやめ、語そのものを禁止する。

将来、別の Rails 設定で `fallbacks` が必要になった場合は、
黙って検証を回避せず、この受け入れ条件と検証方針を明示的に変更する。

### 位置づけ

これは Ruby の意味解析ではなく、プロジェクトの保守規約である。

動的な文字列結合など、静的なトークン検査を回避できる Ruby コードは存在し得る。

```ruby
config.i18n.public_send("fall" + "backs=", true)
```

この経路は連続した `fallbacks` トークンを持たないため、ソース規約では検出できない。
隠さずに受け入れ条件へ明記し、実動作検査とコードレビューで補う。

## 実動作検査

development、test、production をそれぞれ独立したプロセスで boot する。

各環境で次を実行する。

```ruby
key = :p0_t8e_i18n_fallback_probe
I18n.backend.store_translations(:ja, key => "日本語だけの文言")

I18n.t(key, locale: :en, raise: true)
```

期待結果。

```text
I18n::MissingTranslationData
```

日本語が返った場合は検証失敗とする。

3 環境を同一 Ruby プロセスで切り替えない。
I18n Railtie は初期化状態をプロセス内で保持するため、必ず環境ごとに別プロセスで実行する。

production は boot 時に `SECRET_KEY_BASE` を要求する。
検証用の使い捨て値を都度生成し、リポジトリへ秘密情報を持ち込まない。

到達不能な `DATABASE_URL` を与え、boot 中に不用意な DB 接続が起きていないことも併せて検出する。

P0-T8A の production probe は削除せず、この全環境 probe へ統合する。

## 保証範囲

受け入れ条件として次を明記する。

- ソース規約は、一般的な設定記述と連続した `fallbacks` トークンを拒否する
- ソース規約は Ruby のメタプログラミングを完全に静的証明するものではない
- 有効な動作保証は 3 環境の boot probe が担う
- コードレビューを検証器で置き換えない
- 1 設定のための汎用 Ruby 静的解析器を維持しない

「未分類参照 0 件」のような、実態より強い保証を示す表現を使わない。

## 検証器の自己検査

ソース規約の検査関数へ、次を直接渡して確認する。

通すもの。

```ruby
config.i18n.fallbacks = false
# config.i18n.fallbacks = true
```

拒否するもの。

```ruby
config.i18n["fallbacks"] = true
config.i18n.merge!(fallbacks: true)
config.i18n.public_send(:"fallbacks=", true)
config.other.fallbacks = false
```

動的分割文字列を self-test で成功扱いにして隠さない。
それは runtime probe 側の負の検証対象とする。

## 正の検証

- `bash -n scripts/verify-p0` が成功する
- ソース規約の self-test が exit 0 で終了する
- ソース規約が、現在のリポジトリに対して exit 0 で終了する
- 検出が 1 件で、`config/application.rb` の canonical 行である
- development / test / production の boot probe がいずれも exit 0 で終了する
- `docker compose run --rm app bin/verify` が exit 0 で終了する
- `bin/verify --full` が exit 0 で終了する
- `npm run pact:validate` と `npm run pact:lint` が exit 0 で終了する
- 最終 HEAD に対応する GitHub Actions の run が success で終了する

## 負の検証

恒久ファイルを変更せず、一時ツリーまたは一時 bind mount で実施する。

### ソース規約が拒否するもの

```ruby
# config/environments/development.rb
config.i18n["fallbacks"] = true
config.i18n.merge!(fallbacks: true)
config.i18n.public_send(:"fallbacks=", true)
config.other.fallbacks = false
```

```ruby
# config/initializers/i18n_override.rb
Rails.application.config.i18n.fallbacks = true
```

### runtime probe が拒否するもの

次は連続した `fallbacks` トークンを持たないため、静的規約だけへ依存しない。

```ruby
config.i18n.public_send("fall" + "backs=", true)
```

development と production の boot probe が非 0 になることを確認する。

### canonical 異常

```text
正本の削除
false を true へ変更
正本の重複
initializer への正本移動
config/application.rb 内の別形式への変更
```

### 正常系

```text
canonical 行のインデント変更
コメント内の fallbacks
development / test / production の現行設定
```

各ケース終了後、恒久ファイルが元の状態であることを確認する。

## 既存検証の維持

P0-T8E を理由に、次を削除・弱体化しない。

- P0-T8A の production 実動作検査（全環境 probe へ統合する）
- P0-T8 の i18n 構成テスト（12 件）と、boot 後の I18n 実測検査
- `bin/ci` が `bin/verify --full` へだけ委譲する構造

P0-T8B / P0-T8C / P0-T8D の独自解析器の撤去は、
弱体化ではなく、保証範囲を実態へ合わせるための置き換えである。
撤去によって失われる検出（多重代入、括弧付き receiver など）は、
より広いソース規約（`fallbacks` を含むトークンの全面禁止）が包含する。

## 非目標

```text
i18n の設定値そのものの変更
config.i18n.fallbacks 以外の設定項目への同種の検査
Ruby 全体の静的解析基盤の導入
メタプログラミング経由の設定を静的に証明すること
Code Pact 運用文書の再変更
production での翻訳欠落の扱い
言語切替 UI、locale 付き URL、画面の追加
新しい依存関係の追加
新しい永続検証スクリプトの追加
セキュリティと依存関係検査（P0-T9）
Foundation 完了検証（P0-T10）
```

## 変更禁止範囲

```text
config/**（検査対象であり、変更対象ではない）
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
README.md / README.en.md
P1 以降の phase 契約
```

P0-T8、P0-T8A、P0-T8B、P0-T8C、P0-T8D の進捗イベントを変更・削除しない。

`design/` は、`task start` 前の契約コミットと `task finalize --write` による正規更新を除いて変更しない。

## 実装時の注意

- `design/phases/*.yaml` は Code Pact の保護パスであるため、P0-T8E の `writes` へ宣言しない
- 完了処理は P0-T8B で確定した正規順序で行う。
  `task complete` → `task finalize --write` → `verify`
- finalize は dry-run と `--write` の両方で `--audit-strict` を指定し、
  `--base-ref` には P0-T8E の契約コミットを指定する
- `write_audit` の不整合をダミー差分で解消しない。原因を報告して停止する
- 実行していない検証を成功として報告しない
- 行数削減自体を目的にしない。検証器が肥大化していないことの確認として記録する

## 実行後の追記

P0-T8E の完了後、canonical 判定に文字列誤認が残っていることが判明した。

canonical 判定はファイルパスと、トークン位置の行を trim した文字列だけを見ていた。
トークンがコード上の識別子なのか、文字列の内容なのかを確認していなかった。

ヒアドキュメントの内容トークンでは、その内容行そのものが返る。
そのため `:on_tstring_content` でも canonical 行と一致してしまう。

```ruby
ignored = <<~TEXT
config.i18n.fallbacks = false
TEXT
```

```text
type:  on_tstring_content
token: "config.i18n.fallbacks = false\n"
```

実際の設定代入が存在しないにもかかわらず、ソース規約を exit 0 で通過した。

この文書は「文字列、symbol、label、識別子をすべて対象にする」と定めているが、
canonical として許可する側でトークン種別を確認していなかった。
収集は正しく、判定が緩かった。

P0-T8F で canonical 候補を `:on_ident` の `fallbacks` トークンへ限定した。
独自 AST 解析器を再導入しないという本文書の方針は維持している。
詳細は `design/acceptance/P0-T8F-i18n-canonical-token.md` を参照する。
