# P0-T8C 受け入れ条件 — i18n 代入検査の構文木化

この文書は P0-T8C の受け入れ条件の正本とする。
P0-T8C の実装者は、着手前にこの文書を読み、完了報告でここの各項目に対する結果を示す。

## 目的

`config.i18n.fallbacks` への Ruby コード上の代入を構文木から検出し、
次のちょうど 1 件だけを許可する。

```ruby
# config/application.rb
config.i18n.fallbacks = false
```

修正対象は検証器である。現在の設定ファイルの内容そのものは正しい。

## 変更前の問題

P0-T8B の検査は `Ripper.lex` のトークン列から次の並びだけを探していた。

```text
config . i18n . fallbacks =
```

演算子を `=` へ完全一致させているため、次の有効な Ruby 代入を検出しない。

```ruby
config.i18n.fallbacks ||= true
config.i18n.fallbacks &&= false
```

実測では、`config/environments/development.rb` へ上記のいずれを追加しても
P0-T8B の検査は exit 0 で通過した。

そのため次の状態でも「正本が 1 件だけ」と誤判定する。

```ruby
# config/application.rb
config.i18n.fallbacks = false

# config/environments/development.rb
config.i18n.fallbacks ||= true
```

これは P0-T8B の次の要件と矛盾する。

```text
コード上の有効な代入式だけを数える
environment 別ファイルでの再定義を値にかかわらず禁止する
同じファイル内の重複代入を拒否する
Ruby の構文解析を使う
```

字句列は「代入という構文」を表現できない。構文木を検査する。

## 実装要件

### 構文解析

各対象ファイルを `Ripper.sexp` で解析する。

```ruby
sexp = Ripper.sexp(source)
```

`sexp` が `nil` の場合は、対象ファイル名とともに構文解析失敗を表示して exit 1 とする。
解析できないファイルを「代入 0 件」として扱わない。

`Ripper.lex` だけを使った判定へ戻さない。

### 検出対象ノード

構文木を再帰的に走査し、次のノードを検出する。

```text
:assign
:opassign
```

代入左辺が `:field` で、receiver chain の末尾が次の並びであるものを対象とする。

```text
config
i18n
fallbacks
```

receiver の前に何があっても、末尾が `config.i18n.fallbacks` なら検出する。

```ruby
config.i18n.fallbacks = true
Rails.application.config.i18n.fallbacks = true
```

### 記録内容

検出した代入ごとに次を保持する。

```text
path
line
operator
value
```

表示例。

```text
config/application.rb:39 operator== value=false
config/environments/development.rb:80 operator=||= value=true
```

件数だけを表示しない。どこを直せばよいか分かる形で失敗させる。

### 許可条件

次の完全一致だけを許可する。

```text
件数:     1
path:     config/application.rb
operator: =
value:    false
```

`false` は文字列比較ではなく、構文木上の boolean literal として判定する。

次はすべて拒否する。

```text
operator が ||=
operator が &&=
operator が += などその他
value が true
value が動的な式やメソッド呼び出し
value が数値や文字列
value が boolean literal 以外の括弧付き式
config/environments/*.rb での代入（演算子と値にかかわらず）
複数の代入
代入が 0 件
```

### 括弧付きの値

括弧付きの boolean literal は、意味上同一であるため許可する。

```ruby
config.i18n.fallbacks = (false)
```

構文木上の `:paren` を剥がして boolean literal として正規化する。
`(true)` や `(dynamic_value)` は許可しない。

### コメントと文字列

コメントと文字列リテラルは構文木上の代入ノードにならないため、検出しない。

```ruby
# config.i18n.fallbacks = true
message = "config.i18n.fallbacks = true"
```

### メタプログラミング

`public_send(:fallbacks=, true)` のような動的な設定は、
構文木上の代入ノードにならないため、この検査の対象外とする。

設定ファイルでそのような記述を採用しない。
Rails の設定は静的に読めることが前提であり、
動的に設定値を組み立てると、この検査に限らず契約を機械的に確認できなくなる。

### 実装場所

`scripts/verify-p0` の P0-T8B 検査を置き換える。
新しい永続スクリプトファイルを追加しない。

P0-T8A の production boot probe は削除しない。
boot 検査は「実際にフォールバックしないこと」を、
この検査は「設定の正本が 1 か所だけであること」を保証する。役割が異なる。

## 検証器の自己検査

実ファイルを検査する前に、同じ Ruby ブロック内で synthetic probe を実行する。
文字列として直接解析し、期待した演算子と値が取得できることを確認する。

検出するケース。

```ruby
config.i18n.fallbacks = false
config.i18n.fallbacks ||= true
config.i18n.fallbacks &&= false
config.i18n.fallbacks += 1
Rails.application.config.i18n.fallbacks = true
config.i18n.fallbacks = (false)
```

検出しないケース。

```ruby
# config.i18n.fallbacks = true
message = "config.i18n.fallbacks = true"
config.i18n.other = false
config.other.fallbacks = false
```

期待と一致しなければ、scanner self-test として exit 1 とする。

これにより、将来スキャナーを変更した際に `||=` や `&&=` の検出が再び失われても、
通常の `bin/verify` で検出できる。
P0-T8B の欠陥は、検証器自身に対する検証がなかったために見逃された。

## 正の検証

- `bash -n scripts/verify-p0` が成功する
- synthetic probe が exit 0 で終了する
- 単一正本検査が、現在のリポジトリに対して exit 0 で終了する
- 検出された代入がちょうど 1 件で、`config/application.rb` の `=` / `false` である
- P0-T8A の production boot probe が引き続き成功する
- `docker compose run --rm app bin/verify` が exit 0 で終了する
- `bin/verify --full` が exit 0 で終了する
- `npm run pact:validate` と `npm run pact:lint` が exit 0 で終了する
- 最終 HEAD に対応する GitHub Actions の run が success で終了する

## 負の検証

恒久ファイルを変更せず、一時ツリーで次を確認する。
いずれも非 0 で拒否されること。

```text
production へ重複した = false を追加する
development へ = true を追加する
test へ = false を追加する
development へ ||= true を追加する
development へ &&= false を追加する
development へ += 1 を追加する
config/application.rb から正本を削除する
config/application.rb を = true へ変更する
config/application.rb を ||= false へ変更する
```

次は exit 0 を維持すること。

```text
コメント内の例示
文字列リテラル内の例示
空白を増やした plain assignment
行を跨いだ plain assignment
括弧付きの (false)
```

各失敗で、ファイル、行番号、演算子、値が表示されることを確認する。

各ケース終了後、恒久ファイルが元の状態であることを確認する。

## 既存検証の維持

P0-T8C を理由に、P0-T1 から P0-T8B までで確立した検証を削除・弱体化・並べ替えしない。

- P0-T8A の production boot probe
- P0-T8 の i18n 構成テスト（12 件）と累積検証
- P0-T8B の対象 4 ファイル限定という範囲設定
- `bin/ci` が `bin/verify --full` へだけ委譲する構造

## 非目標

次は P0-T8C で実装しない。

```text
i18n の設定値そのものの変更
Code Pact 運用文書の再変更
docs/code-pact/agent-instructions.md の更新
production での翻訳欠落の扱い
言語切替 UI、locale 付き URL、画面の追加
新しい依存関係の追加
新しい永続検証スクリプトの追加
config.i18n.fallbacks 以外の設定項目への同種の検査
メタプログラミング経由の設定の検出
セキュリティと依存関係検査（P0-T9）
Foundation 完了検証（P0-T10）
```

## 変更禁止範囲

次のファイルを P0-T8C で変更しない。

```text
config/application.rb
config/environments/**
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
docs/code-pact/agent-instructions.md
docs/development/code-pact.md
design/rules/code-pact-execution.md
README.md / README.en.md
P1 以降の phase 契約
```

P0-T8、P0-T8A、P0-T8B の進捗イベントを変更・削除しない。

`design/` は、`task start` 前の契約コミットと `task finalize --write` による正規更新を除いて変更しない。

## 実装時の注意

- `design/phases/*.yaml` は Code Pact の保護パスであるため、P0-T8C の `writes` へ宣言しない
- 完了処理は P0-T8B で確定した正規順序で行う。
  `task complete` → `task finalize --write` → `verify`
- finalize は dry-run と `--write` の両方で `--audit-strict` を指定し、
  `--base-ref` には P0-T8C の契約コミットを指定する
- `write_audit` の不整合をダミー差分で解消しない。原因を報告して停止する
- 実行していない検証を成功として報告しない
