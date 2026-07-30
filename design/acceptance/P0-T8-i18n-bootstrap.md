# P0-T8 受け入れ条件 — 日本語・英語の i18n 基盤

この文書は P0-T8 の受け入れ条件の正本とする。
P0-T8 の実装者は、着手前にこの文書を読み、完了報告でここの各項目に対する結果を示す。

## 目的

`docs/development/language-policy.md` が定める
「利用者に表示される文字列は日本語と英語の両方を提供する」を、
以後のすべての機能が守れる形で基盤へ固定する。

P0-T8 で実装するのは基盤だけとする。

- 対応言語を日本語と英語だけへ限定する
- 既定言語を日本語とする
- 翻訳の欠落を開発時とテスト時に検出する
- 日英どちらか一方にしか存在しない翻訳キーを検出する
- Rails 標準機能の日本語ロケールデータを依存として導入する

画面、URL、言語切替はこのタスクで扱わない。

## 対応言語

```text
ja
en
```

これ以外のロケールを受理しない。

## 既定言語

```text
ja
```

## 設定

`config/application.rb` へ次を設定する。

```ruby
config.i18n.available_locales = %i[ja en]
config.i18n.default_locale = :ja
config.i18n.enforce_available_locales = true
config.i18n.fallbacks = false
```

`enforce_available_locales` は Rails の既定値と同じだが明示する。
対応言語の制約を、Rails の既定値の記憶ではなくプロジェクトの設定として読める状態へ固定する。

次は行わない。

- `I18n.locale` を initializer でグローバルに設定する
- `config.time_zone` を変更する
- `config/routes.rb` を変更する
- `ApplicationController` を変更する

## 翻訳欠落

development と test では、翻訳の欠落を例外として検出する。

```ruby
config.i18n.raise_on_missing_translations = true
```

Rails 生成時のコメントアウト行がある場合は、その行を有効化する。
同じ設定を別の行へ重複して追加しない。

production の `raise_on_missing_translations` は変更しない。
production で翻訳欠落をどう扱うか（例外化するか、監視へ送るか、
利用者へどう見せるか）は、運用方針とエラー監視が整うフェーズで決定する。

## フォールバック

日本語に存在して英語に存在しない文言を、日本語へ暗黙にフォールバックさせない。
日英同時実装の原則を、フォールバックで隠さない。

これは production を含むすべての実行環境で成立させる。
フォールバックは「欠落をどう扱うか」ではなく「欠落を欠落として観測できるか」の問題であり、
有効なままでは欠落そのものが観測できない。
したがって、上の `raise_on_missing_translations` に関する後続判断を待たない。

P0-T8 の実装時点では、`config/application.rb` の `fallbacks = false` を
`config/environments/production.rb` に残った Rails 生成時の
`config.i18n.fallbacks = true` が上書きしており、production だけが対象外になっていた。
この不整合は P0-T8A で解消済みである。

- 正本は `config/application.rb` の `config.i18n.fallbacks = false` だけとする
- production 側の上書きは削除する
- production の実測検証は `design/acceptance/P0-T8A-production-i18n-fallback.md` を参照する

## 共通ロケールデータ

Rails 標準機能の日本語ローカライズデータとして `rails-i18n` の 8.1 系を使用する。

```ruby
gem "rails-i18n", "~> 8.1.0"
```

Active Model のエラー文言、日付、時刻、数値形式を自前で全面的に複製しない。
複製すると Rails の更新へ追随できず、翻訳の網羅性も維持できない。

lockfile は固定 Ruby 環境で更新する。

```bash
docker compose run --rm app bundle lock
```

`Gemfile.lock` を手作業で編集しない。
Rails 本体および他の直接依存のバージョンを、このタスクで更新しない。

## アプリケーション所有辞書

次の 2 ファイルを初期辞書とする。

```text
config/locales/ja.yml
config/locales/en.yml
```

初期キーは次だけとする。

```yaml
ja:
  application:
    name: RoleWeave
```

```yaml
en:
  application:
    name: RoleWeave
```

- Rails 生成時の `hello` サンプルを削除する
- Rails 生成時の長い説明コメントを残さない
- i18n キーは英語で書く
- 日本語版と英語版で事実を一致させる
- 今回使用しない画面文言を先回りして追加しない
- 求人、応募、認証など後続機能のキーを追加しない

## キー同型性

アプリケーションが所有する日本語辞書と英語辞書は、葉キーの集合を一致させる。
`rails-i18n` と Rails 本体が提供する共通ロケールデータは、この検査の対象にしない。

次を失敗として扱う。

```text
日本語だけに存在するキー
英語だけに存在するキー
空文字
nil
文字列以外の値
想定外のトップレベルロケール
YAML として解析できない辞書
同じ mapping 内の重複キー
```

トップレベルキーの存在確認だけで済ませない。葉キーまで再帰的に列挙して比較する。

YAML の解析では、オブジェクト生成と alias を許可しない。
Psych は同じ mapping 内の重複キーを後勝ちで受理するため、
重複の検出は解析木をたどって行う。

## 検証の配置

P0-T8 の静的検証と実測検証は `scripts/verify-p0` へ実装し、
P0-T8 の進捗イベントが記録された時点で有効にする。
Docker 検証より前へ置き、契約違反を build より先に失敗させる。

Rails の実行を伴う契約は `test/configuration/i18n_configuration_test.rb` でも検証する。
`bin/verify` はすでに Rails test を実行するため、i18n 専用の検証入口を追加しない。

## 正の検証

### 構成テスト

`test/configuration/i18n_configuration_test.rb` で次を検証する。

- `I18n.available_locales` の集合が `ja` と `en` だけである
- `I18n.default_locale` が `:ja` である
- `I18n.with_locale(:fr)` が `I18n::InvalidLocale` を発生させる
- 英語で欠落した文言が日本語へ置き換わらない
- test 環境で翻訳の欠落が `I18n::MissingTranslationData` を発生させる
- `rails-i18n` 由来の日本語ロケールデータを参照できる
- `application.name` が日本語と英語の両方に存在し、いずれも `RoleWeave` である
- アプリケーション辞書の葉キー集合が日本語と英語で一致する
- アプリケーション辞書の値がすべて空でない文字列である
- アプリケーション辞書に `hello` キーが存在しない

順序だけに依存する比較を書かない。
`rails-i18n` の確認は内部実装クラス名へ依存せず、公開された I18n API を通して行う。

テストの説明は日本語で記述する。

### 累積検証

`scripts/verify-p0` で次を検査する。

- `config/locales/ja.yml` が存在する
- `config/locales/en.yml` が存在する
- `test/configuration/i18n_configuration_test.rb` が存在する
- `Gemfile` の `rails-i18n` 宣言がちょうど 1 件である
- boot 後の対応ロケールが `ja` と `en` だけである
- boot 後の既定ロケールが `ja` である
- 未登録ロケールが拒否される
- フォールバックが無効である
- test 環境で翻訳欠落が検出される
- `application.name` が日英両方から取得できる
- `hello` サンプルが残っていない

設定ファイルの記述ではなく、boot 後の I18n の実測値を検査する。

### コマンド

- `docker compose run --rm app bin/verify` が exit 0 で終了する
- `bin/verify --full` が exit 0 で終了する
- `npm run pact:validate` と `npm run pact:lint` が exit 0 で終了する
- 最終 HEAD に対応する GitHub Actions の run が success で終了する

## 負の検証

- `:fr` が `I18n::InvalidLocale` で拒否される
- 英語で欠落したアプリケーション文言が日本語へ自動的に置き換わらない
- 日英のキー集合が一致しない辞書を、構成テストが成功扱いしない
- スコープ外のファイルに差分がない

キー同型性の負の検証は、恒久ファイルを破壊的に書き換えて行わない。

## 既存検証の維持

P0-T8 を理由に、P0-T1 から P0-T7C までで確立した検証を削除・弱体化・並べ替えしない。

- `bin/ci` が引き続き `bin/verify --full` へだけ委譲する
- GitHub Actions の Workflow を変更しない
- `bin/verify` へ i18n 専用のコマンドを追加しない

## 非目標

次は P0-T8 で実装しない。

```text
日本語トップページ
英語トップページ
言語切替リンク
/ja、/en などのロケール付きルーティング
params[:locale] によるロケール選択
Cookie やセッションへの言語保存
アカウントへの言語設定保存
Accept-Language による自動判定
ApplicationController へのロケール切替処理
HTML の lang 属性変更
翻訳管理サービスとの連携
翻訳管理用の独自 DSL
JavaScript 側の翻訳基盤
production での翻訳欠落の扱い（例外化・監視・利用者への表示）
セキュリティと依存関係検査（P0-T9）
Foundation 完了検証（P0-T10）
```

リクエスト単位の言語選択と URL 設計は、P1 の画面・ルーティング契約と同時に決定する。

production の i18n フォールバックは非目標ではない。
P0-T8 の実装時点では対象外としていたが、それは目的を満たさない範囲設定であり、
P0-T8A で是正した。

## 変更禁止範囲

次のファイルを P0-T8 で変更しない。

```text
config/routes.rb
config/environments/production.rb（P0-T8A で是正対象とした）
app/**
README.md / README.en.md
compose.yaml
Dockerfile
package.json / package-lock.json
.github/**
bin/**
scripts/verify-p0-docker
scripts/verify-github-actions
scripts/verify-github-actions-self-test
docs/**
P1 以降の phase 契約
```

`design/` は、`task start` 前の契約コミットと `task finalize --write` による正規更新を除いて変更しない。

変更対象を増やす必要が生じた場合は、その場で拡張せず、残課題として報告する。

## 実装時の注意

- `design/phases/*.yaml` は Code Pact の保護パスであるため、P0-T8 の `writes` へ宣言しない。
  契約の詳細化は `task start` 前の契約コミットで済ませ、作業ツリーを clean にしてから開始する
- `Gemfile.lock` の更新は固定 Ruby 環境のコンテナで行い、差分の範囲を確認してからコミットする
- finalize は dry-run と `--write` の両方で `--audit-strict` を指定する
- `write_audit` の `outside_declared` と `declared_unused` を空にしてから `--write` する
- `write_audit` の不整合をダミー差分で解消しない。原因を報告して停止する
- 実行していない検証を成功として報告しない
