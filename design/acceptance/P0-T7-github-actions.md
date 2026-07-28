# P0-T7 受け入れ条件 — GitHub Actions による統一検証

この文書は P0-T7 の受け入れ条件の正本とする。
P0-T7 の実装者は、着手前にこの文書を読み、完了報告でここの各項目に対する結果を示す。

## 目的

Pull Request と `main` ブランチへの push に対して、GitHub Actions 上で RoleWeave の統一検証を実行する。

検証内容を GitHub Actions へ複製せず、既存の正規入口だけを使用する。

```text
GitHub Actions
    ↓
bin/ci
    ↓
bin/verify --full
    ↓
scripts/verify-p0
    ↓
scripts/verify-p0-docker
```

Workflow の責務は、実行環境の準備と `bin/ci` の起動だけとする。

GitHub Actions の ubuntu runner は Linux ホストであるため、
本タスクは P0-T6B（コンテナ内の作業ツリー所有者）へ依存する。

## Workflow の責務

Workflow が行うのは次の 6 つだけとする。

```text
1. リポジトリを checkout する
2. .ruby-version に従って Ruby を準備する
3. Gemfile.lock に従って Ruby 依存関係を準備する
4. .node-version に従って Node.js を準備する
5. package-lock.json に従って Node.js 依存関係を準備する
6. bin/ci を実行する
```

次を Workflow へ直接記述しない。

```text
bin/rubocop
bin/rails test
bin/rails db:prepare
bin/rails zeitwerk:check
npm run pact:validate
npm run pact:lint
scripts/verify-p0
scripts/verify-p0-docker
docker compose build
docker compose run
bundler-audit
brakeman
```

これらの実行内容は `bin/verify` 以下を正本とする。

## Trigger

対象は次の 2 つだけとする。

```text
pull_request
push to main
```

次は追加しない。

```text
pull_request_target
schedule
workflow_dispatch
workflow_run
release
deployment
```

`pull_request_target` は fork の PR に対して書き込み権限を持つ文脈でチェックアウト対象を実行するため、
検証目的の Workflow では使用しない。
`workflow_dispatch` は必要になった時点で別タスクとして判断する。

## 権限

Workflow 全体の権限は次だけとする。

```yaml
permissions:
  contents: read
```

次を禁止する。

```text
contents: write
pull-requests: write
issues: write
id-token: write
packages: write
actions: write
security-events: write
```

job 単位で権限を上書きしない。

## 実行環境

```yaml
runs-on: ubuntu-24.04
```

`ubuntu-latest` は使用しない。実行環境が暗黙に更新されると、検証結果の再現性が失われる。

## Action 参照

使用を許可する Action は次の 3 つだけとする。

```text
actions/checkout
ruby/setup-ruby
actions/setup-node
```

すべて完全長 40 桁のコミット SHA へ固定する。
タグとブランチは可変であり、同じ参照が別の実装へ差し替わり得る。

各 `uses` 行の末尾には、対応するリリースタグをコメントで記録する。
SHA だけでは、どのリリースを固定したのかが読めなくなる。

```yaml
uses: owner/action@0123456789abcdef0123456789abcdef01234567 # v1.2.3
```

### 承認済みの固定

「40 桁の 16 進数であること」だけでは、承認していない任意のコミットを許してしまう。
Action 名・SHA・リリースタグの組を構造検査側にも登録し、Workflow と完全一致させる。

```text
actions/checkout    3d3c42e5aac5ba805825da76410c181273ba90b1  v7.0.1
ruby/setup-ruby     95ef2b042f9d7a56d8268cba8559e2842e2ad01b  v1.321.0
actions/setup-node  820762786026740c76f36085b0efc47a31fe5020  v7.0.0
```

Action を更新するときは、Workflow と構造検査の一覧を同一 PR で更新し、
公式リポジトリでタグと SHA の対応を確認する。
fork や第三者のミラーを参照しない。

## checkout 設定

```yaml
with:
  persist-credentials: false
```

CI は push も tag 作成も行わない。checkout 後に認証情報を残さない。

## Ruby と Node.js の設定

バージョンの正本は既存の version file とする。Workflow へ数値を重複記述しない。

```yaml
with:
  ruby-version: .ruby-version
  bundler-cache: true
```

```yaml
with:
  node-version-file: .node-version
  cache: npm
```

Node.js 依存関係は `npm ci` で準備する。
`npm install` は解決結果によって `package-lock.json` を書き換え得るため使用しない。

## 検証入口

実行する検証コマンドは次の 1 つだけとする。

```yaml
run: bin/ci
```

Workflow から `bin/verify --full` を直接呼ばない。
`bin/ci` の委譲契約そのものを継続的に使用し、実運用の経路として検証し続ける。

## リソース制御

同じブランチまたは PR の古い実行を打ち切る。group は次と完全に一致させる。

```yaml
concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

「空でないこと」だけを検査しない。
`global` のような固定値へ退行すると、無関係な PR の実行まで打ち切られる。

job には上限時間を設定する。

```yaml
timeout-minutes: 30
```

上限に達した場合、値を安易に延長せず、停止箇所を調査する。

## 禁止する構成

次を追加しない。

```text
GitHub Actions services
PostgreSQL service container
job-level container
Docker Buildx
Docker layer cache
Redis
OpenSearch
matrix
複数 job
Artifact upload
Coverage upload
CodeQL
Dependabot
デプロイ処理
シークレット参照
環境保護設定
```

PostgreSQL と Docker の検証は、既存の `bin/verify --full` 以下が専用の Compose project で実行する。
GitHub Actions 側へ別の PostgreSQL を定義すると、検証対象の構成が二重になる。

## Workflow 構造検査

`scripts/verify-github-actions` を追加し、上記の契約を構造として検査する。

- Ruby で実装し、実行可能にする
- 新規の依存関係を追加せず、標準添付の `yaml` で解析する
- 引数なしの場合は `.github/workflows/ci.yml` を検査する
- 検査対象を 1 引数で受け取れるようにし、負の検証を破壊的な編集なしで行えるようにする
- 2 つ以上の引数は拒否する

検査項目は次のとおり。

```text
Workflow 名が CI であること
trigger が pull_request と main への push だけであること
pull_request_target がないこと
permissions が contents: read だけであること
concurrency の group が承認済みの式と完全一致すること
cancel-in-progress が true であること
job が verify の 1 つだけであること
runner が ubuntu-24.04 であること
timeout-minutes が 30 であること
services がないこと
job container がないこと
environment がないこと
steps の順序と責務が一致すること
Action 名・SHA・リリースタグの組が承認済み一覧と完全一致すること
checkout の persist-credentials が false であること
Ruby が .ruby-version を参照すること
bundler-cache が true であること
Node.js が .node-version を参照すること
npm cache が有効であること
依存準備が npm ci であること
最終検証が bin/ci であること
continue-on-error がないこと
secrets への参照がないこと
個別の検証コマンドが Workflow にないこと
```

### 生の `uses` 行

`uses` の値と末尾コメントは解析結果に完全には残らないため、生の行も検査する。

正規形式は次だけとする。

```yaml
uses: owner/repository@<40桁SHA> # <承認済みタグ>
```

次を拒否する。

```text
"uses": owner/repository@...
'uses': owner/repository@...
uses: owner/repository@v7
uses: owner/repository@<承認外の SHA> # 正しいタグ
uses: owner/repository@<承認済み SHA> # 別のタグ
末尾コメントのない uses 行
```

キーを引用符で囲むと、素朴な行検査を迂回できる。
`uses` を含む行の総数と、正規形式に一致する行の数と順序の両方を検査する。

### シークレット参照

GitHub の式には次の複数の記法がある。`secrets.` だけを探す検査では不十分である。

```text
secrets.TOKEN
secrets['TOKEN']
secrets["TOKEN"]
```

いずれも拒否する。

## 構造検査自身の回帰検査

`scripts/verify-github-actions-self-test` を追加し、構造検査が契約違反を実際に拒否することを、
P0 の累積検証の一部として毎回確認する。

- 正規の Workflow が構造検査を通過すること（陽性対照）
- 一時ディレクトリへ複製した Workflow へ変異を加え、すべて非 0 で拒否されること
- 一時ファイルは確実に削除し、`.github/workflows/ci.yml` を破壊しないこと

変異には最低限次を含める。

```text
Action を可変タグへ変更する
Action を承認外の 40 桁 SHA へ変更する
リリースタグのコメントだけを変更する
uses キーを引用符付きへ変更する
uses 行のコメントを削除する
concurrency group を固定値へ変更する
secrets.TOKEN を参照する
secrets['TOKEN'] を参照する
permissions を contents: write へ変更する
pull_request を pull_request_target へ変更する
bin/ci を bin/verify --full へ変更する
bin/ci の前へ個別の検証コマンドを追加する
2 つ目の job を追加する
runner を ubuntu-latest へ変更する
version file の値を Workflow へ直接記述する
npm ci を npm install へ変更する
persist-credentials を true へ変更する
timeout-minutes を削除する
concurrency を削除する
service container を追加する
continue-on-error を追加する
```

負の検証を実行時の手作業に依存させない。
検証器が退行した場合、その退行自体を累積検証で失敗させる。

## P0 累積検証への接続

`scripts/verify-p0` の P0-T7 以前の拒否処理を、開始後は存在検査へ切り替える。

- `.github/workflows` と `.github/workflows/ci.yml` が存在すること
- `.github/dependabot.yml` が存在しないこと（P0-T9 の非目標）
- `.github/workflows` 直下の Workflow が `ci.yml` の 1 つだけであること
- `scripts/verify-github-actions` が成功すること
- `scripts/verify-github-actions-self-test` が成功すること

構造検査は Docker build より前へ置き、契約違反を build より先に失敗させる。

## 正の検証

- `scripts/verify-github-actions` が exit 0 で終了する
- `scripts/verify-github-actions-self-test` が exit 0 で終了する
- `npm run pact:validate` と `npm run pact:lint` が exit 0 で終了する
- `docker compose run --rm app bin/verify` が exit 0 で終了する
- `bin/verify --full` が exit 0 で終了する
- `bin/ci` が exit 0 で終了する
- `bin/ci unexpected-argument` が非 0 で終了する
- P0-T3 から P0-T6B までの既存検証がすべて成功する
- 最終 HEAD に対応する GitHub Actions の run が success で終了する

## 負の検証

`scripts/verify-github-actions-self-test` が上記の変異をすべて拒否すること。
`scripts/verify-p0` 側では、次を Docker build より前に拒否すること。

```text
.github/workflows へ 2 つ目の Workflow を追加する
.github/workflows/ci.yml を契約違反へ書き換える
```

一時変更はすべて破棄し、一時ファイルと Docker resource を残さない。

## 既存検証の維持

P0-T7 を理由に、P0-T3 / P0-T4 / P0-T4A / P0-T5 / P0-T6 / P0-T6A / P0-T6B で確立した検証を
削除・弱体化しない。
置き換えるのは `scripts/verify-p0` の GitHub Actions 拒否処理だけとし、より厳格な構造検査へ差し替える。

## 非目標

次は P0-T7 で実装しない。

```text
日本語・英語の初期設定（P0-T8）
bundler-audit と Brakeman の必須化（P0-T9）
Dependabot
CodeQL
GitHub Pages
デプロイ
Docker イメージの公開
Artifact upload
カバレッジサービス
テスト並列化
matrix build
macOS / Windows / ARM CI
定期実行
手動実行
Release workflow
Redis / OpenSearch
業務機能・画面・データモデル
```

セキュリティ Action や Dependabot を「ついで」に追加しない。

## 変更禁止範囲

次のファイルを P0-T7 で変更しない。

```text
app/**
config/**
db/**
test/**
Gemfile / Gemfile.lock
package.json / package-lock.json
Dockerfile
compose.yaml
bin/ci
bin/verify
bin/setup
bin/docker-entrypoint
scripts/verify-p0-docker
README.md / README.en.md
docs/**
.github/pull_request_template.md
P1 以降の phase 契約
```

`design/` は、`task start` 前の契約コミットと `task finalize --write` による正規更新を除いて変更しない。

## 実装時の注意

- `design/phases/*.yaml` は Code Pact の保護パスであるため、P0-T7 の `writes` へ宣言しない。
  契約の登録は `task start` 前のコミットで済ませ、作業ツリーを clean にする
- Action の SHA は実装時点で公式リポジトリから取得し、タグとの対応を確認する
- finalize は dry-run と `--write` の両方で `--audit-strict` を指定する。
  `--base-ref` には P0-T7 の契約コミットを指定する
- `write_audit` の不整合をダミー差分で解消しない。原因を報告して停止する
- CI が失敗している状態でタスクを完了としない。
  古い run や別 SHA に対する成功を証跡にしない
