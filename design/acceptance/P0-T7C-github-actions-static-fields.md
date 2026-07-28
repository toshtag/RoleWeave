# P0-T7C 受け入れ条件 — GitHub Actions 検証器の表示名と数値スカラー

この文書は P0-T7C の受け入れ条件の正本とする。
P0-T7C の実装者は、着手前にこの文書を読み、完了報告でここの各項目に対する結果を示す。

## 目的

`scripts/verify-github-actions` が、表示名と数値スカラーへ任意の表現を許すことで、
シークレット相当の参照と非正規な数値表現を受理する問題を修正する。

修正対象は検証器である。`.github/workflows/ci.yml` 自体に問題はない。

## 変更前の問題

### `github` コンテキスト経由でシークレット参照禁止を迂回できる

シークレット参照の検査は `secrets` コンテキストだけを対象にしていた。

```ruby
SECRET_REFERENCE = /\bsecrets\b/i
```

一方で job 名は検査しておらず、step 名は空でないことしか確認していなかった。

```ruby
check(failures, step["name"].to_s.strip != "", ...)
```

そのため、次の変異がいずれも構造検査を通過した。

```yaml
- name: ${{ github.token }}
- name: ${{ github['token'] }}
- name: ${{ toJSON(github) }}
- name: ${{ github }}
```

```yaml
jobs:
  verify:
    name: ${{ github.ref }}
```

`github.token` は `GITHUB_TOKEN` シークレットと機能的に同等であり、
`github` コンテキスト全体にはそうした機密情報が含まれる。

したがって現在の構造検査が保証しているのは
「`secrets` コンテキストを参照しない」ことだけであり、
「Workflow からシークレットやトークンを参照しない」ことは保証できていない。

### `timeout-minutes` の型とソース表現が固定されていない

検査は値の比較だけだった。

```ruby
job["timeout-minutes"] == 30
```

Ruby では整数 `30` と浮動小数点数 `30.0` が等値になるため、型が違っても通過する。
次の 4 件はいずれも構造検査を通過した。

```yaml
timeout-minutes: 30.0
timeout-minutes: !!float 30
timeout-minutes: 0x1e
timeout-minutes: +30
```

P0-T7A では真偽値についてソース上の正規表現まで固定している。
同じ原則を数値スカラーへも適用する。

## 実装要件

### job 名

次と完全一致すること。

```yaml
name: 統一検証
```

次を拒否する。

```text
空文字
別の固定文字列
GitHub 式
github.token
github['token']
toJSON(github)
```

### step 名

順序を含めて次と完全一致すること。

```text
1. リポジトリを取得
2. Rubyを準備
3. Node.jsを準備
4. Node.js依存関係を準備
5. 統一検証
```

「空でないこと」だけの検査は廃止する。

表示名を動的にする必要はない。正規値へ固定することで、
表示名を経由したあらゆる式の評価を拒否できる。

### トークン参照

表示名の固定に加えて、防御を重ねる。
解析済み Workflow の文字列から次を検出し、拒否する。

```text
github.token
github['token']
github["token"]
```

この検査だけに依存しない。表示名の完全固定も併せて維持する。

### `timeout-minutes`

解析結果について次を要求する。

```text
型: Integer
値: 30
```

ソース上でも次と完全一致させる。

```yaml
timeout-minutes: 30
```

次を拒否する。

```text
30.0
!!float 30
0x1e
+30
"30"
${{ 30 }}
```

P0-T7A で導入した真偽値のソース表現一覧へ `timeout-minutes` を加え、
一覧の名称とコメントを「ソーススカラーの正規形」を説明する内容へ更新する。

### authority コメント

`scripts/verify-github-actions` と `scripts/verify-github-actions-self-test` の
先頭コメントが参照する正本へ、本文書を追加する。

```text
design/acceptance/P0-T7-github-actions.md
design/acceptance/P0-T7A-github-actions-verifier-hardening.md
design/acceptance/P0-T7B-github-actions-yaml-integrity.md
design/acceptance/P0-T7C-github-actions-static-fields.md
```

## 正の検証

- 正規の `.github/workflows/ci.yml` が構造検査を通過する
- `scripts/verify-github-actions` が exit 0 で終了する
- `scripts/verify-github-actions-self-test` が exit 0 で終了する
- `npm run pact:validate` と `npm run pact:lint` が exit 0 で終了する
- `docker compose run --rm app bin/verify` が exit 0 で終了する
- `bin/verify --full` が exit 0 で終了する
- `bin/ci` が exit 0 で終了する
- P0-T7 から P0-T7B までで確立した 50 変異が引き続きすべて拒否される
- 最終 HEAD に対応する GitHub Actions の run が success で終了する

## 負の検証

一時ディレクトリへ複製した Workflow へ次の変異を加え、いずれも非 0 で拒否されること。

```text
job 名を別の固定値へ変更する
job 名で GitHub 式を参照する
job 名で github.token を参照する
step 名を別の固定値へ変更する
step 名で github.token を参照する
step 名で github['token'] を参照する
step 名で github["token"] を参照する
step 名で toJSON(github) を参照する
step 名で裸の github コンテキストを参照する
timeout-minutes を 30.0 へ変更する
timeout-minutes を !!float 30 へ変更する
timeout-minutes を 0x1e へ変更する
timeout-minutes を +30 へ変更する
timeout-minutes を "30" へ変更する
```

修正前は上記のうち 12 件が通過していた事実を、完了報告と PR 本文へ記載する。

既存 50 変異を自己テストから削除しない。

## 非目標

次は P0-T7C で実装しない。

```text
Workflow 本体の変更
Action バージョンと SHA の更新
Docker 実装の変更
GitHub 式そのものの評価
外部 lint（actionlint 等）の導入
新規の gem と npm 依存の追加
日本語・英語の初期設定（P0-T8）
セキュリティと依存関係検査（P0-T9）
```

## 変更禁止範囲

次のファイルを P0-T7C で変更しない。

```text
.github/workflows/ci.yml
bin/docker-entrypoint
bin/ci
bin/verify
bin/setup
scripts/verify-p0
scripts/verify-p0-docker
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

`design/` は、`task start` 前の契約コミットと `task finalize --write` による正規更新を除いて変更しない。

## 実装時の注意

- `design/phases/*.yaml` は Code Pact の保護パスであるため、P0-T7C の `writes` へ宣言しない
- 検証器だけを先に push し、自己テストのない中間状態を完了扱いしない
- finalize は dry-run と `--write` の両方で `--audit-strict` を指定する。
  `--base-ref` には P0-T7C の契約コミットを指定する
- `write_audit` の不整合をダミー差分で解消しない。原因を報告して停止する
- 古い HEAD に対する GitHub Actions の成功を最終証跡として再利用しない
