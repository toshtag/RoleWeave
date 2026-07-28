# P0-T7A 受け入れ条件 — GitHub Actions 検証器の YAML 正規形

この文書は P0-T7A の受け入れ条件の正本とする。
P0-T7A の実装者は、着手前にこの文書を読み、完了報告でここの各項目に対する結果を示す。

## 目的

`scripts/verify-github-actions` が、Ruby の YAML 1.1 解釈と
GitHub Actions のソース契約との差によって、契約違反を正規構造として受理する問題を修正する。

修正対象は検証器である。`.github/workflows/ci.yml` 自体に問題はない。

## 変更前の問題

### Trigger のソースキーが `on` に限定されていない

`scripts/verify-github-actions` は、Ruby の YAML パーサーが `on` を真偽値 `true` として
解釈することへ対応するため、真偽値キーを一律で `on` へ正規化していた。

```ruby
triggers = workflow.key?("on") ? workflow["on"] : workflow[true]
top_level_keys = workflow.keys.map { |key| key == true ? "on" : key }
```

YAML 1.1 は `true` / `yes` / `ON` などをすべて真偽値として扱うため、
ソース上のキーを次のいずれへ変更しても、解析結果は同じ真偽値キーになる。

```yaml
true:
yes:
ON:
```

その結果、いずれの変異も構造検査を通過した。

GitHub Actions が実行イベントとして扱う正規のキーは `on` である。
Ruby 側の解釈差を吸収することと、ソース上のキーを `on:` へ限定することは分けなければならない。
現状では、GitHub が Trigger として扱わない可能性があるソースを、検証器が正しいと判定できる。

Workflow の Trigger が失われれば CI そのものが実行されなくなるため、
この穴は他の検査項目より優先度が高い。

### YAML 1.1 の真偽値別名が通過する

同じ解釈差により、次の変異もすべて通過した。

```yaml
cancel-in-progress: yes
persist-credentials: no
bundler-cache: yes
```

Ruby の解析結果はそれぞれ `true` / `false` / `true` になる。

GitHub Actions の入力は YAML 1.2 系の真偽値表現を前提とし、
Actions Toolkit の `getBooleanInput` が受け付けるのは大文字・小文字違いを含む
`true` と `false` だけである。`yes` と `no` は対象外となる。

### `secrets` コンテキスト全体への参照を検出できない

シークレット参照の検査は、次の 2 記法だけを対象にしていた。

```ruby
SECRET_REFERENCE = /\bsecrets\s*(?:\.|\[)/i
```

そのため、コンテキスト全体を関数へ渡す記法が通過した。

```yaml
- name: ${{ toJSON(secrets) }}
- name: ${{ secrets }}
```

受け入れ条件は「シークレット参照がないこと」であり、
特定プロパティへの参照だけを禁止するものではない。

### Docker 累積検証の authority コメントが古い

`scripts/verify-p0-docker` の先頭コメントは P0-T4 / P0-T5 だけを対象として説明しているが、
実際には P0-T6B の検証も含んでいる。
このプロジェクトではコメントを Agent が authority として読むことを前提とするため、
実装内容と一致させる。

## 実装要件

### トップレベルキーのソース検査

解析結果とは別に、ソース上のトップレベル mapping key を収集し、
次と順序まで完全一致することを検査する。

```text
name
on
permissions
concurrency
jobs
```

- コメント行、空行、インデントされた行は対象から除く
- 収集した一覧と期待する一覧を配列として完全一致で比較する

次を拒否する。

```yaml
true:
yes:
True:
ON:
"on":
'on':
```

解析結果側の真偽値キー正規化は維持してよい。
正規の `on:` を Ruby が真偽値へ解釈する問題を吸収するために必要である。
ソース上の正規性は別の検査で保証する。

### 真偽値のソース表現

次のキーについて、ソース上の値を抽出し、各 1 件かつ小文字の正規表現であることを検査する。

```text
cancel-in-progress  true
persist-credentials false
bundler-cache       true
```

次を拒否する。

```text
yes
no
on
off
YES
NO
True
False
```

今回の契約では小文字の `true` と `false` だけを正規形とする。

### シークレット参照

`secrets` コンテキストへの参照自体を禁止する。

```ruby
SECRET_REFERENCE = /\bsecrets\b/i
```

検査対象は解析済み Workflow の文字列に限る。コメント内の説明文は対象にしない。

次をすべて拒否する。

```text
secrets.TOKEN
secrets['TOKEN']
secrets["TOKEN"]
toJSON(secrets)
contains(secrets, 'TOKEN')
format('{0}', secrets)
${{ secrets }}
```

値が実際に展開されるか、ログでマスクされるかを成功条件にしない。

### 自己テストの拡張

`scripts/verify-github-actions-self-test` へ、少なくとも次の変異を追加する。

```text
on を true へ変更する
on を yes へ変更する
on を ON へ変更する
on を引用符付き "on" へ変更する
cancel-in-progress を yes へ変更する
persist-credentials を no へ変更する
bundler-cache を yes へ変更する
step の name から toJSON(secrets) を参照する
step の name から ${{ secrets }} を参照する
```

Action 固定の変異は、現在 `actions/checkout` だけを対象にしている。
3 つの Action それぞれについて SHA 改ざんとリリースタグ改ざんを行う。

```text
actions/checkout
ruby/setup-ruby
actions/setup-node
```

自己テストの目的は、実装が現時点で汎用であることの確認ではなく、
将来一部の Action だけ検査対象から漏れた場合にそれを検出することにある。

### Docker 累積検証コメント

`scripts/verify-p0-docker` の先頭コメントだけを更新する。実行コードは変更しない。

```text
P0-T4 / P0-T5 / P0-T6B の Docker 検証
```

受け入れ条件の正本一覧へ次を追加する。

```text
design/acceptance/P0-T6B-container-git-ownership.md
```

## 正の検証

- 正規の `.github/workflows/ci.yml` が構造検査を通過する
- `scripts/verify-github-actions` が exit 0 で終了する
- `scripts/verify-github-actions-self-test` が exit 0 で終了する
- `npm run pact:validate` と `npm run pact:lint` が exit 0 で終了する
- `docker compose run --rm app bin/verify` が exit 0 で終了する
- `bin/verify --full` が exit 0 で終了する
- `bin/ci` が exit 0 で終了する
- P0-T3 から P0-T7 までの既存検証がすべて成功する
- 最終 HEAD に対応する GitHub Actions の run が success で終了する

## 負の検証

一時ディレクトリへ複製した Workflow へ次の変異を加え、いずれも非 0 で拒否されること。

```text
on: を true: へ変更する
on: を yes: へ変更する
on: を ON: へ変更する
on: を "on": へ変更する
cancel-in-progress: true を yes へ変更する
persist-credentials: false を no へ変更する
bundler-cache: true を yes へ変更する
step の name で toJSON(secrets) を参照する
step の name で ${{ secrets }} を参照する
3 つの Action それぞれの SHA を改ざんする
3 つの Action それぞれのリリースタグを改ざんする
```

修正前は上記のうち 9 件が通過していた事実を、完了報告と PR 本文へ記載する。

P0-T7 で確立した既存の変異検査も、引き続きすべて拒否されること。

## 非目標

次は P0-T7A で実装しない。

```text
Workflow 本体の変更
Action バージョンと SHA の更新
Docker 実装の変更
YAML パーサーの差し替え
外部 lint（actionlint 等）の導入
日本語・英語の初期設定（P0-T8）
セキュリティと依存関係検査（P0-T9）
```

## 変更禁止範囲

次のファイルを P0-T7A で変更しない。

```text
.github/workflows/ci.yml
bin/docker-entrypoint
bin/ci
bin/verify
bin/setup
scripts/verify-p0
Dockerfile
compose.yaml
app/**
config/**
db/**
test/**
Gemfile / Gemfile.lock
package.json / package-lock.json
README.md / README.en.md
docs/**
P1 以降の phase 契約
```

`scripts/verify-p0-docker` はコメントだけを変更し、実行コードを変更しない。

`design/` は、`task start` 前の契約コミットと `task finalize --write` による正規更新を除いて変更しない。

## 実装時の注意

- `design/phases/*.yaml` は Code Pact の保護パスであるため、P0-T7A の `writes` へ宣言しない
- 検証器だけを先に push し、自己テストのない中間状態を完了扱いしない
- finalize は dry-run と `--write` の両方で `--audit-strict` を指定する。
  `--base-ref` には P0-T7A の契約コミットを指定する
- `write_audit` の不整合をダミー差分で解消しない。原因を報告して停止する
- 古い HEAD に対する GitHub Actions の成功を最終証跡として再利用しない
