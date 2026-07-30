# P0-T8F 受け入れ条件 — canonical 設定の文字列誤認の防止

この文書は P0-T8F の受け入れ条件の正本とする。
P0-T8F の実装者は、着手前にこの文書を読み、完了報告でここの各項目に対する結果を示す。

## 目的

ソース規約が canonical として許可するのを、
実際の Ruby コード上にある次の 1 件だけへ限定する。

```ruby
# config/application.rb
config.i18n.fallbacks = false
```

修正対象は検証器である。現在の設定ファイルの内容そのものは正しい。

## 変更前の問題

P0-T8E の canonical 判定は、ファイルパスと、
トークン位置の行を trim した文字列だけを見ていた。

トークンがコード上の識別子なのか、文字列の内容なのかを確認していなかった。
ヒアドキュメントの内容トークンでは、その内容行そのものが返る。

```ruby
ignored = <<~TEXT
config.i18n.fallbacks = false
TEXT
```

```text
type:  on_tstring_content
token: "config.i18n.fallbacks = false\n"
```

実際の設定代入が存在しないにもかかわらず、ソース規約は exit 0 で通過した。

収集側は「文字列、symbol、label、識別子をすべて対象にする」で正しかった。
canonical として許可する側の判定が緩かった。

## 実装要件

### 全参照の収集

P0-T8E と同様に、コメントと埋め込みドキュメント以外で、
トークン内容に `fallbacks` を含むものをすべて収集する。

収集情報へ次を含める。

```text
path
line
text
type
token
```

### canonical 候補

次の完全一致だけを canonical として許可する。

```text
path:  config/application.rb
text:  config.i18n.fallbacks = false
type:  :on_ident
token: fallbacks
```

参照が 0 件のときに例外を起こさない順序を維持する。

### 拒否するもの

行の内容が canonical と同じでも拒否する。

```ruby
ignored = <<~TEXT
config.i18n.fallbacks = false
TEXT
```

```ruby
message = "config.i18n.fallbacks = false"
```

次も引き続き拒否する。

```ruby
config.i18n["fallbacks"] = true
config.i18n[:fallbacks] = true
config.i18n.merge!(fallbacks: true)
config.i18n.public_send(:"fallbacks=", true)
config.other.fallbacks = false
```

### 許可するもの

```ruby
config.i18n.fallbacks = false
```

```ruby
    config.i18n.fallbacks = false
```

```ruby
# config.i18n.fallbacks = true
config.i18n.fallbacks = false
```

### エラー表示

失敗時の表示へトークン種別とトークン値を加える。

```text
config/application.rb:2:
  text=config.i18n.fallbacks = false
  type=on_tstring_content
  token=config.i18n.fallbacks = false
```

通常の失敗メッセージを過度に長くしない。

### 実装の制約

- 独自 AST 解析器を再導入しない
- AST 走査、receiver 解析、代入構文解析を追加しない
- トークン属性を 2 つ追加確認するだけの最小修正に留める

P0-T8E で撤去したものを戻さない。
P0-T8B から P0-T8D で繰り返した「構文を列挙して補修する」方向へ戻さない。

## 保証範囲

- canonical 候補が文字列、symbol、label ではないことを確認する
- Ruby コードの制御フローや変数の意味までは解析しない
- 実際の動作保証は 3 環境の boot probe が担う
- コードレビューを検証器で置き換えない

## 検証器の自己検査

P0-T8E の accepted probes と rejected probes を維持する。

追加する拒否ケース。

```ruby
ignored = <<~TEXT
config.i18n.fallbacks = false
TEXT
```

```ruby
message = "config.i18n.fallbacks = false"
```

self-test と実ファイル検査は、引き続き同じ `inspect_sources` を通す。

確認事項。

```text
canonical                        exit 0
インデント付き canonical         exit 0
コメント + canonical             exit 0
ヒアドキュメント内の canonical   exit 1
通常文字列内の canonical         exit 1
string index / symbol index      exit 1
merge! / symbol setter           exit 1
無関係な fallbacks               exit 1
```

## 正の検証

- `bash -n scripts/verify-p0` が成功する
- ソース規約の self-test が exit 0 で終了する
- ソース規約が、現在のリポジトリに対して exit 0 で終了する
- development / test / production の boot probe がいずれも exit 0 で終了する
- `docker compose run --rm app bin/verify` が exit 0 で終了する
- `bin/verify --full` が exit 0 で終了する
- `npm run pact:validate` と `npm run pact:lint` が exit 0 で終了する
- 最終 HEAD に対応する GitHub Actions の run が success で終了する

## 負の検証

恒久ファイルを変更せず、一時ツリーで実施する。

```text
canonical をヒアドキュメントへ置換     -> 非 0
canonical を通常文字列へ置換           -> 非 0
canonical を削除                       -> 非 0
canonical を true へ変更               -> 非 0
現在の正本                             -> exit 0
コメント + 正本                        -> exit 0
```

各ケース終了後、恒久ファイルが元の状態であることを確認する。

## 既存検証の維持

次を削除・弱体化しない。

- 全 `config/**/*.rb` の列挙
- 構文解析失敗の拒否
- コメントと埋め込みドキュメントの除外
- 文字列、symbol、label を含む `fallbacks` トークンの収集
- development / test / production の独立 boot probe
- P0-T8 の i18n 構成テスト（12 件）
- `bin/ci` から `bin/verify --full` への委譲
- P0-T8E の保証範囲の明記

## 非目標

```text
i18n の設定値そのものの変更
独自 AST 解析器の再導入
Ruby の制御フローや変数の意味解析
config.i18n.fallbacks 以外の設定項目への同種の検査
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

P0-T8 から P0-T8E までの進捗イベントを変更・削除しない。

`design/` は、`task start` 前の契約コミットと `task finalize --write` による正規更新を除いて変更しない。

## 実装時の注意

- `design/phases/*.yaml` は Code Pact の保護パスであるため、P0-T8F の `writes` へ宣言しない
- 完了処理は P0-T8B で確定した正規順序で行う。
  `task complete` → `task finalize --write` → `verify`
- finalize は dry-run と `--write` の両方で `--audit-strict` を指定し、
  `--base-ref` には P0-T8F の契約コミットを指定する
- `write_audit` の不整合をダミー差分で解消しない。原因を報告して停止する
- 実行していない検証を成功として報告しない
