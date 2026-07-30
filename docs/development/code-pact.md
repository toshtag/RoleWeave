# code-pact 運用ガイド

このプロジェクトは、開発タスクの制御面として [code-pact](https://github.com/toshtag/code-pact) を使用する。

この文書は日本語版を正本とする。

## 1. 適用範囲

- code-pact は開発時の制御面である
- アプリケーションの実行時依存ではない
- プロダクトの業務機能へ組み込まない

`package.json` の `devDependencies` へ完全固定したバージョンで導入する。
グローバルインストールを前提にしない。`npm exec -- code-pact` またはスクリプト経由で実行する。

```json
{
  "devDependencies": {
    "code-pact": "2.8.0"
  }
}
```

Node.js の開発基準は `.node-version` で固定する。
`package.json` の `engines.node` と一致させる。

## 2. 標準ライフサイクル

1 タスクにつき、次の順序で実行する。

```bash
npm exec -- code-pact task prepare <TASK_ID> --agent generic --json
```

```bash
npm exec -- code-pact task start <TASK_ID> --agent generic
```

`task start` はタスク契約とフェーズ `verification.commands` をロックする。
`reads`、`writes`、`acceptance_refs`、依存関係、検証コマンドは start 前に確認し、
必要な制御面変更をコミットして作業ツリーを clean にしてから start する。
start 後にこれらを変更すると `TASK_CONTRACT_DRIFT` が発生し、`task complete` が失敗する。

実装したあと、完了記録を行う。

```bash
npm exec -- code-pact task complete <TASK_ID> --agent generic
```

`task complete` はフェーズの `verification.commands` を実行し、done イベントを記録する。

finalize は、まず dry-run で結果と `write_audit` を確認してから書き込む。
dry-run と `--write` の両方で `--audit-strict` を指定する。

```bash
npm exec -- code-pact task finalize <TASK_ID> --audit-strict --json
```

```bash
npm exec -- code-pact task finalize <TASK_ID> --audit-strict --write --json
```

dry-run の結果を確認せずに `--write` を実行しない。
`write_audit` の `outside_declared` と `declared_unused` を空にしてから `--write` する。

`task finalize --write` は、フェーズ YAML のタスク `status` を `done` へ更新する。

最後にタスクの状態を検証する。

```bash
npm exec -- code-pact verify --phase <PHASE_ID> --task <TASK_ID>
```

タスクを指定した `verify` は、done イベントとフェーズ YAML の `status` の両方を確認する。
`status` を更新するのは `task finalize --write` であるため、
finalize より前に実行すると `task_status` で必ず失敗する。

したがってタスクを指定した `verify` は、complete と finalize の後に行う。

```text
task prepare
task start
実装
task complete
task finalize --audit-strict --json         （dry-run）
task finalize --audit-strict --write --json
code-pact verify --phase <PHASE_ID> --task <TASK_ID>
```

`verify` は毎回フェーズ検証コマンドを実行する。
P0 では Docker build を含む `bin/verify --full` であるため、
順序を誤ると数分の実行が丸ごと無駄になる。

最後の `verify` が失敗した場合、その結果を成功として扱わない。
すでに finalize 済みのタスクを無断で書き換えず、是正タスクを作って積み上げる。

進捗イベント（`.code-pact/state/events/**`）は write audit の対象外のため、`writes` へ宣言しない。
`design/roadmap.yaml`、`design/phases/*.yaml`、`.code-pact/**` は Code Pact の保護パスであり、
実行中のタスクがこれらを `writes` へ宣言していると、strict な `plan lint` が
`TASK_WRITES_PROTECTED_PATH` を終了コードへ反映する。
P0 の検証は strict lint を含むため、制御面自体を変更するタスクは、
その変更を `task start` 前のコミットで済ませる。

プロジェクト全体の整合性は次で確認する。

```bash
npm run pact:validate
```

```bash
npm run pact:lint
```

## 3. ブートストラップ例外

P0-T2 は code-pact 自体を導入するタスクであるため、通常のライフサイクルを完全には適用できない。
この例外は P0-T2 に限る。

- P0-T1 は code-pact 導入以前に完了した既存タスクである。
  P0-T2 は P0-T1 に依存するため、依存解決のために完了実績を記録する必要がある。
  実行していない検証を成功として扱わないよう、`task complete` ではなく
  `task record-done` を使い、`source: external` のイベントとして記録する。
  検証コマンドを実行したかのような履歴を作らない。

  ```bash
  npm exec -- code-pact task record-done P0-T1 --agent generic \
    --evidence "<マージ済みコミットまたは PR>" --notes "<記録理由>"
  ```
- P0-T2 は、最低限の制御面（`design/roadmap.yaml`、`design/phases/`、P0-T2 の契約）を
  生成したあとに `task prepare` と `task start` を実行する。
- P0-T3 以降は、実装前に必ず `task prepare` と `task start` を実行する。

## 4. 信頼境界

- `verify` と `task complete` は、フェーズ定義に書かれたシェルコマンドを実行する
- `design/phases/*.yaml` の `verification.commands` を変更・追加する差分は、実行前にレビューする
- 外部から取り込んだ未確認のコマンドやスクリプトを検証コマンドへ登録しない
- `task finalize` の `write_audit` は、宣言した write scope と実際の差分を突き合わせる補助であり、
  レビューの代替ではない

## 5. アダプター

初期導入は `generic` だけとする。

```bash
npm exec -- code-pact adapter install generic --json
```

- Claude Code、Codex、Cursor、Gemini CLI などの専用アダプターは、実際に必要になったタスクで追加する
- 同じ目的の生成指示ファイルを手作業で複製しない
- `CLAUDE.md`、`AGENTS.md`、`GEMINI.md`、`.cursor/`、`.claude/` はこのプロジェクトでは生成しない

### 生成物の扱い

`docs/code-pact/agent-instructions.md` は code-pact が管理する生成物である。

- 手作業で恒久的な修正を入れない。編集すると `adapter doctor` が `ADAPTER_FILE_DRIFT` を報告する
- 生成内容がプロジェクトの方針と矛盾する場合は、`design/constitution.md` と `design/rules/` 側を正本として扱う
- 再生成は `npm exec -- code-pact adapter upgrade generic --write --json` で行う

RoleWeave で使用する正規コマンドは、常に次の形とする。

```text
npm exec -- code-pact ... --agent generic
```

生成された Agent 指示に `--agent claude-code` が記載されていても使用しない。
[`design/rules/code-pact-execution.md`](../../design/rules/code-pact-execution.md) を優先する。

現時点で確認している生成物の注意点は次のとおり。

- コマンド例の `--agent claude-code` は code-pact 側の汎用例であり、8 か所に出現する。
  このプロジェクトでは `--agent generic` を指定する。
- 「プロジェクト固有の規約」節が `design/rules/coding-style.md` を参照する。
  `code-pact init` のサンプル規約は削除したが、同じパスへ RoleWeave 固有の実ルールを
  置き直しているため参照は解決する。
- 上記の矛盾は生成物を編集して解消せず、`design/rules/code-pact-execution.md` と
  `design/rules/coding-style.md` 側で補完している。

### コンテキストパック

`generic` アダプターのコンテキストパックは `.context/generic/` へ書き出される。
`.context/` は `code-pact init` が `.gitignore` へ追加するため、リポジトリへコミットしない。
必要になった時点で `task prepare --detail full` または `task context` で生成する。

## 6. フェーズ検証コマンド

フェーズの `verification.commands` は、そのフェーズで実装した内容を実際に検証するものにする。
Code Pact の構造検査（`validate` / `plan lint`）だけを残さない。

P0 の検証コマンドは [`scripts/verify-p0`](../../scripts/verify-p0) とする。
このスクリプトは進捗イベントを見て、開始済みタスクに対応する検証を自動的に有効にする。

- Code Pact 制御面の検査は常に実行する。
  `plan lint` は必ず `--strict`（`npm run pact:lint`）で実行する。
  strict でのみ終了コードへ反映される警告を見逃さないため
- Kamal、Thruster、開発用コンテナ、Rails の master key と credentials は、
  P0 全体を通して混入を失敗として扱う
- P0-T3 が開始された時点から Rails 実体の検査を有効にする
  （固定バージョン、`.gitignore` / `.gitattributes` / `.rubocop.yml`、
  PostgreSQL なしでの boot、README の状態）
- P0-T4 が開始されるまでは Docker 関連ファイルの混入を失敗として扱う
- P0-T7 が開始されるまでは GitHub Actions 関連ファイルの混入を失敗として扱う
  （Rails 標準の `bin/ci` と `config/ci.rb` はローカル検証の入口であり、拒否しない）

P0-T4 以降は、各タスクでこのスクリプトへ検証を追加する。
P0-T6 で `bin/verify` が完成した時点で、P0 の `verification.commands` を `bin/verify` へ一本化する。

## 7. 制御面の構成

```text
.code-pact/
├── project.yaml              プロジェクト設定とアダプター登録
├── agent-profiles/           アダプターごとのプロファイル
├── adapters/                 アダプター生成物のマニフェスト
├── model-profiles/           モデル階層の定義
└── state/                    進捗イベントとベースライン

design/
├── brief.md                  プロジェクト概要
├── constitution.md           判断の基本原則
├── roadmap.yaml              フェーズ索引
├── phases/                   フェーズ契約（P0 から P15）
├── acceptance/               タスクごとの受け入れ条件
└── rules/                    タスク実行時のルール

scripts/
└── verify-p0                 P0 の累積検証
```

フェーズとタスクの状態の正本は `design/` 配下に一本化する。
`docs/` 配下に状態付きの別ロードマップを作らない。
