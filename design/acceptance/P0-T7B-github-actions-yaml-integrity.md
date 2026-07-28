# P0-T7B 受け入れ条件 — GitHub Actions 検証器の YAML ストリーム完全性

この文書は P0-T7B の受け入れ条件の正本とする。
P0-T7B の実装者は、着手前にこの文書を読み、完了報告でここの各項目に対する結果を示す。

## 目的

`scripts/verify-github-actions` が、検査対象ファイルの一部だけを見て
「Workflow は契約どおりである」と判定する問題を修正する。

修正対象は検証器である。`.github/workflows/ci.yml` 自体に問題はない。

## 変更前の問題

検証器は解析の入口で次を実行していた。

```ruby
workflow = YAML.safe_load(raw)
```

この 1 行には 2 つの前提が隠れている。

### 重複した mapping key を後勝ちで受理する

Psych は同じ mapping 内に同名キーが複数あると、現在の実行環境では後方の値を残す。
そのため、前方へ別の値を追加しても、検証器には正規の最終値だけが見える。

```yaml
permissions:
  contents: write
  contents: read
```

```yaml
jobs:
  verify:
    name: 無効な定義
    runs-on: ubuntu-latest
    steps: []
  verify:
    name: 統一検証
```

```yaml
- name: 統一検証
  run: echo bypass
  run: bin/ci
```

YAML の mapping key は一意でなければならない。
重複キーは、パーサーごとに先勝ち・後勝ち・エラーの差が生じる余地を作るため、
検証器と GitHub 側で解釈がずれる原因になる。

### 最初の document だけを検査する

`YAML.safe_load(raw)` は、現在の実行環境では最初の YAML document だけを返す。
そのため、正規 Workflow の後ろへ別 document を追加しても、
後続部分が構造検査や `secrets` 検査の対象にならない。

```yaml
# 正規の Workflow
---
"x": "${{ secrets.TOKEN }}"
```

明示的な document 終端の後ろへ解析不能な内容を追加しても通過する。

```yaml
# 正規の Workflow
...

${{ secrets.TOKEN }}
```

現在の検証器が保証しているのは、
「先頭から読み取れた最初の document が、検証済み Workflow に見える」ことだけであり、
「ファイル全体が、検証済みの 1 つの Workflow である」ことではない。

これは P0-T7A で解消した YAML 1.1 解釈差と同じ種類の問題である。
解析結果だけを見て、ソースの実体を検査していない。

## 実装要件

### YAML ストリーム

- 入力全体を `Psych.parse_stream` で解析する
- YAML document がちょうど 1 件であることを検査する
- document の root が mapping であることを検査する
- 2 件目以降の document を拒否する
- 空の 2 件目 document も拒否する
- document 終端の後ろに置かれた内容を拒否する
- 解析できない後続内容を無視しない
- `YAML.safe_load` は、ストリーム全体の検証が成功した後にだけ使用する

構文エラーは、これまでどおり検査対象ファイルのパスとともに報告する。

### mapping key の一意性

- 解析木を再帰的に巡回し、すべての mapping を検査する
- 同じ mapping 内でキーが一意であることを検査する
- block mapping と flow mapping の両方を対象にする
- 引用符の有無が異なっても、同じ scalar 値なら重複として扱う
- scalar でない mapping key を拒否する
- 重複を検出した場合、キー名、mapping の位置、最初の出現行、重複行をエラーへ含める

別々の mapping に同じキーが存在することは問題にしない。
判定は同一 mapping 内に限る。

### authority コメント

`scripts/verify-github-actions` と `scripts/verify-github-actions-self-test` の
先頭コメントが参照する正本を、実際の 3 文書へ合わせる。

```text
design/acceptance/P0-T7-github-actions.md
design/acceptance/P0-T7A-github-actions-verifier-hardening.md
design/acceptance/P0-T7B-github-actions-yaml-integrity.md
```

処理説明そのものを増やさず、authority の一覧だけを正確にする。

## 正の検証

- 正規の `.github/workflows/ci.yml` が構造検査を通過する
- `scripts/verify-github-actions` が exit 0 で終了する
- `scripts/verify-github-actions-self-test` が exit 0 で終了する
- `npm run pact:validate` と `npm run pact:lint` が exit 0 で終了する
- `docker compose run --rm app bin/verify` が exit 0 で終了する
- `bin/verify --full` が exit 0 で終了する
- `bin/ci` が exit 0 で終了する
- P0-T7 と P0-T7A で確立した 38 変異が引き続きすべて拒否される
- 最終 HEAD に対応する GitHub Actions の run が success で終了する

## 負の検証

一時ディレクトリへ複製した Workflow へ次の変異を加え、いずれも非 0 で拒否されること。

```text
on 配下の push を重複させる
permissions 配下の contents を重複させる
jobs 配下の verify を重複させる
step 配下の run を重複させる
step 配下の name を重複させる
flow mapping 内のキーを重複させる
引用符の有無だけが異なるキーを重複させる
空の 2 件目 document を追加する
引用符付きキーを持つ 2 件目 document を追加する
secrets 参照を含む 2 件目 document を追加する
document 終端の後ろへ裸の scalar を追加する
document 終端の後ろへ secrets 式を追加する
```

修正前は上記のうち 10 件が通過していた事実を、完了報告と PR 本文へ記載する。

既存 38 変異を自己テストから削除しない。

## 非目標

次は P0-T7B で実装しない。

```text
Workflow 本体の変更
Action バージョンと SHA の更新
Docker 実装の変更
YAML パーサーの差し替え
外部 lint（actionlint 等）の導入
新規の gem と npm 依存の追加
日本語・英語の初期設定（P0-T8）
セキュリティと依存関係検査（P0-T9）
```

## 変更禁止範囲

次のファイルを P0-T7B で変更しない。

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

- `design/phases/*.yaml` は Code Pact の保護パスであるため、P0-T7B の `writes` へ宣言しない
- 検証器だけを先に push し、自己テストのない中間状態を完了扱いしない
- finalize は dry-run と `--write` の両方で `--audit-strict` を指定する。
  `--base-ref` には P0-T7B の契約コミットを指定する
- `write_audit` の不整合をダミー差分で解消しない。原因を報告して停止する
- 古い HEAD に対する GitHub Actions の成功を最終証跡として再利用しない
