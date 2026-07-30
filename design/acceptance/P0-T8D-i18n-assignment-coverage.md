# P0-T8D 受け入れ条件 — i18n 代入検査の構文網羅性

この文書は P0-T8D の受け入れ条件の正本とする。
P0-T8D の実装者は、着手前にこの文書を読み、完了報告でここの各項目に対する結果を示す。

## 目的

`config.i18n.fallbacks` を変更できる静的な Ruby 構文を漏れなく拒否し、
次のちょうど 1 件だけを許可する。

```ruby
# config/application.rb
config.i18n.fallbacks = false
```

修正対象は検証器である。現在の設定ファイルの内容そのものは正しい。

## 変更前の問題

P0-T8C は `:assign` と `:opassign` だけを収集し、
receiver が直接 `:call` であることを前提としていた。

そのため次はいずれも exit 0 で通過した。

```ruby
config.i18n.fallbacks, other = true, nil
(config.i18n).fallbacks = true
(Rails.application.config.i18n).fallbacks = true
```

多重代入は `:massign` であり、`:assign` でも `:opassign` でもない。
括弧付き receiver は `:paren` を挟むため、receiver chain の走査から外れる。

値側の括弧は正規化していたが、receiver 側の括弧は正規化していなかった。
括弧の正規化は値と receiver で別の責務であり、片方だけでは網羅できない。

## 実装要件

### 検出対象ノード

```text
:assign
:opassign
:massign
```

### receiver の正規化

単一式を包む `:paren` を再帰的に剥がす共通ヘルパーを用意し、
receiver chain の走査へ適用する。

次はいずれも 1 件の代入として検出する。

```ruby
(config.i18n).fallbacks = true
((config.i18n)).fallbacks = true
(Rails.application.config.i18n).fallbacks = true
(config).i18n.fallbacks = true
```

値側の括弧正規化と receiver 側の括弧正規化は、別の責務として扱う。
既存の boolean literal 判定を弱体化しない。

### 多重代入

`:massign` の左辺を再帰的に走査し、
`config.i18n.fallbacks` の field が 1 件でも含まれていれば検出する。

```ruby
config.i18n.fallbacks, other = true, nil
other, config.i18n.fallbacks = nil, true
config.i18n.fallbacks, = true
```

記録は次のとおりとする。

```text
operator: massign
value: (multiple-assignment)
```

多重代入は値にかかわらず許可しない。
右辺と左辺を対応付けて許可判定しない。多重代入構文そのものを禁止する。

設定の正本を 1 行の plain assignment へ固定するのが目的であり、
多重代入で書ける必要はない。左右の対応を解析する複雑さを検証器へ持ち込まない。

### 未分類参照の fail-closed 検査

対象 4 ファイルを `Ripper.lex` でも解析し、
コードトークンとして現れる次の識別子の位置を収集する。

```text
:on_ident / fallbacks
:on_ident / fallbacks=
```

コメントと文字列リテラルはトークン種別が異なるため、この収集の対象にならない。

構文木スキャナーが認識した代入 target の `@ident` 位置（行と列）と照合し、
分類されていないコード上の参照が 1 件でもあれば拒否する。

これにより、少なくとも次を静かに通過させない。

```ruby
config.i18n.public_send(:fallbacks=, true)
config.i18n.send(:fallbacks=, true)

i18n_config = config.i18n
i18n_config.fallbacks = true
```

これらを正しい設定方法としてサポートする必要はない。
検証不能な記述として拒否する。

構文木で分類できないものを「代入 0 件」として扱わない。
検査器が理解できない記述は、通すのではなく止める。

次は引き続き許可する。

```ruby
# config.i18n.fallbacks = true
message = "config.i18n.fallbacks = true"
```

失敗時は次を表示する。

```text
unclassified i18n fallback reference
path:line:column token=<内容>
```

### 許可条件

次の完全一致だけを許可する。

```text
件数:                    1
path:                    config/application.rb
operator:                =
value:                   false
unclassified references: 0
```

### 実装場所

`scripts/verify-p0` の P0-T8B / P0-T8C 検査を拡張する。
新しい永続スクリプトファイルを追加しない。

P0-T8A の production boot probe は削除しない。

## 検証器の自己検査

P0-T8C の synthetic probe を維持したうえで、次を追加する。

検出するケース。

```ruby
(config.i18n).fallbacks = true
((config.i18n)).fallbacks = true
(Rails.application.config.i18n).fallbacks = true
(config).i18n.fallbacks = true
config.i18n.fallbacks, other = true, nil
other, config.i18n.fallbacks = nil, true
config.i18n.fallbacks, = true
```

括弧付き receiver は `operator==`、多重代入は `operator=massign` として検出する。

未分類参照として拒否するケース。

```ruby
config.i18n.public_send(:fallbacks=, true)
config.i18n.send(:fallbacks=, true)
i18n_config = config.i18n
i18n_config.fallbacks = true
```

これらは「代入として正しく認識する」のではなく、「未分類参照として拒否する」ことを確認する。

検出も未分類扱いもしないケース。

```ruby
# config.i18n.fallbacks = true
message = "config.i18n.fallbacks = true"
config.i18n.other = false
config.other.fallbacks = false
```

`config.other.fallbacks = false` は `fallbacks` 識別子を含むが、
代入 target として構文木から認識されるため未分類にはならない。
ただし receiver が `config.i18n` ではないため、正本の件数には数えない。

期待と一致しなければ scanner self-test として exit 1 とする。

## 正の検証

- `bash -n scripts/verify-p0` が成功する
- synthetic probe が exit 0 で終了する
- 単一正本検査が、現在のリポジトリに対して exit 0 で終了する
- 検出された代入がちょうど 1 件で、未分類参照が 0 件である
- P0-T8A の production boot probe が引き続き成功する
- `docker compose run --rm app bin/verify` が exit 0 で終了する
- `bin/verify --full` が exit 0 で終了する
- `npm run pact:validate` と `npm run pact:lint` が exit 0 で終了する
- 最終 HEAD に対応する GitHub Actions の run が success で終了する

## 負の検証

恒久ファイルを変更せず、一時ツリーで実施する。

P0-T8C で確立した 9 ケースをすべて維持する。

```text
production へ重複した = false
development へ = true
test へ = false
development へ ||= true
development へ &&= false
development へ += 1
config/application.rb から正本を削除
config/application.rb を = true へ
config/application.rb を ||= false へ
```

次を追加し、いずれも非 0 で拒否されること。

```text
development へ多重代入を追加する
development へ対象 field が 2 番目の多重代入を追加する
development へ括弧付き receiver を追加する
development へ二重括弧付き receiver を追加する
development へ Rails.application 付き括弧 receiver を追加する
development へ public_send(:fallbacks=, true) を追加する
development へ send(:fallbacks=, true) を追加する
config.i18n を別変数へ代入し、その変数の fallbacks を変更する
```

次は exit 0 を維持すること。

```text
コメント内の fallbacks
文字列リテラル内の fallbacks
空白を増やした正本
行を跨いだ正本
括弧付きの値 (false)
```

各失敗で、少なくとも次のいずれかが表示されること。

```text
path
line
operator
value
未分類参照の token 位置
```

各ケース終了後、恒久ファイルが元の状態であることを確認する。

## 既存検証の維持

P0-T8D を理由に、P0-T1 から P0-T8C までで確立した検証を削除・弱体化・並べ替えしない。

- P0-T8A の production boot probe
- P0-T8 の i18n 構成テスト（12 件）と累積検証
- P0-T8B の対象 4 ファイル限定という範囲設定
- P0-T8C の `:assign` / `:opassign` 検出、boolean literal 判定、値側の括弧正規化
- `bin/ci` が `bin/verify --full` へだけ委譲する構造

## 非目標

次は P0-T8D で実装しない。

```text
i18n の設定値そのものの変更
メタプログラミング経由の設定を「正しい設定方法」としてサポートすること
config.i18n.fallbacks 以外の設定項目への同種の検査
Ruby 全体の静的解析基盤の導入
Code Pact 運用文書の再変更
production での翻訳欠落の扱い
言語切替 UI、locale 付き URL、画面の追加
新しい依存関係の追加
新しい永続検証スクリプトの追加
セキュリティと依存関係検査（P0-T9）
Foundation 完了検証（P0-T10）
```

## 変更禁止範囲

次のファイルを P0-T8D で変更しない。

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

P0-T8、P0-T8A、P0-T8B、P0-T8C の進捗イベントを変更・削除しない。

`design/` は、`task start` 前の契約コミットと `task finalize --write` による正規更新を除いて変更しない。

## 実装時の注意

- `design/phases/*.yaml` は Code Pact の保護パスであるため、P0-T8D の `writes` へ宣言しない
- 完了処理は P0-T8B で確定した正規順序で行う。
  `task complete` → `task finalize --write` → `verify`
- finalize は dry-run と `--write` の両方で `--audit-strict` を指定し、
  `--base-ref` には P0-T8D の契約コミットを指定する
- `write_audit` の不整合をダミー差分で解消しない。原因を報告して停止する
- 実行していない検証を成功として報告しない
