# Agent Instructions — Generic

> このファイルは [code-pact](https://github.com/toshtag/code-pact) によって管理されています。
> Copy or symlink it into your agent's instruction location (e.g. .cursorrules,
> GEMINI.md, or any other tool-specific path).

## Prerequisites

Ensure `code-pact` is available in your PATH. During local development,
`pnpm link --global` or a local tarball install both work.

## タスクの進め方

0. タスクを prepare する — タスク単位の単一の入口。デフォルト (minimal) では現在の状態、goal、宣言された読み書きスコープ、完了条件、検証コマンド、`next` アクション、そして full envelope を取得するための `more` コマンドを含むコンパクトな作業指示を返す。`--detail full` またはいずれかの budget flag を使うと、実行推奨 (モデル階層、エフォート、計画姿勢、バジェット)、コンテキストパックのメタデータ、構造化された `next_action`、そして次に実行すべき正確なコマンドの `commands` 辞書も返る:
   ```sh
   code-pact task prepare <task-id> --agent generic --json
   ```
   minimal モードではコンテキストパックを書き込まず、重い取得処理も行わない。`next.type` が `inspect_decision` の場合、推奨情報が必要な場合、またはコンテキストパックの具体化が指示された場合に限り full detail を取得する。full モードでは返された `commands` 辞書をそのまま使ってライフサイクルを進める。

1. `task prepare` の外でコンテキストパックが必要な場合のみ、直接取得する (診断用 — `task prepare` は既にそのメタデータを返している):
   ```sh
   code-pact task context <task-id> --agent generic
   ```

2. タスクを実装する。

3. タスクを完了としてマークする。verify を実行し、成功すれば `done` イベントを `.code-pact/state/events/` に記録する:
   ```sh
   code-pact task complete <task-id> --agent generic
   ```
   verify が失敗した場合、このコマンドは exit 1 を返し progress イベントは記録されません。
   `done` イベントが既に存在する場合は no-op (`already_done: true`) となります。

4. 結果をユーザーに報告する。

> 低レベルコマンド `code-pact verify --phase <p> --task <t>` は、進捗イベントを記録せずに verify 出力を確認したい場合に利用できます。
>
> 非自明なタスク開始前に `code-pact validate --json` でプロジェクト全体の整合性 (schema / manifest / plan) を確認する。
>
> **低レベルコマンド:** `code-pact pack` は安定していますが、エージェント向けの入口としては `code-pact task context <task-id>` を推奨します。

## Agent contract

code-pact の正規ワークフローには 3 つの軸があります。準拠するエージェントは 3 軸すべてを尊重します。完全な envelope 仕様は [`docs/cli-contract.md`](https://github.com/toshtag/code-pact/blob/main/docs/cli-contract.md) を参照してください。

`data.commands.context` は `task prepare` を `--detail full` または full detail を強制する明示的な budget flag で実行した場合にのみ存在します。存在する場合は返されたまま使ってください。解決済み context budget を再構築したり、広げたり、置き換えたりしないでください。budget 付き context には決定論的な構造 projection が含まれる場合があります。まず projected form を使用してください。minimal モードで context が必要な場合は `data.more.command` で full envelope を取得してください。具体的な不足が作業を妨げ、かつ `data.deferred_context.retrieve_command` が non-null の場合だけ正確な原文 section を取得してください。`null` の場合は manifest reference から取得 command を組み立てないでください。

### When to invoke code-pact

プロジェクト初期化（CI / 非対話可）:

```sh
code-pact init --non-interactive --agent claude-code --locale ja-JP --json

# plan brief: 3 つの相互排他的モード
code-pact plan brief --from-file brief.yaml --json
# または: cat brief.yaml | code-pact plan brief --stdin --json
# または: code-pact plan brief --what "..." --who "..." --differentiator "..." --json

# plan constitution: 同じ 3 モード構造
code-pact plan constitution --from-file constitution.yaml --json
# または: code-pact plan constitution --description "..." --principle "..." --principle "..." --json
```

タスクごと (推奨入口: `task prepare`):

```sh
# デフォルト minimal — context pack の build/取得なしのコンパクトな作業指示
code-pact task prepare <task-id> --agent claude-code --json

# Full detail — 推薦、context pack メタデータ、next_action、commands
code-pact task prepare <task-id> --agent claude-code --detail full --json

# 明示的な budget flag は full detail を強制する（context pack をサイジングする用途）
code-pact task prepare <task-id> --agent claude-code --budget-bytes 100000 --json

# prepare の応答に応じてエージェントが呼び出す lifecycle verb:
code-pact task start    <task-id> --agent claude-code
# ... 実装 ...
code-pact verify --phase <p> --task <task-id>
code-pact task complete <task-id> --agent claude-code
code-pact task finalize <task-id> --write --json

# 補助 diagnostic:
code-pact task context <task-id> --agent claude-code
code-pact recommend --phase <p> --task <task-id> --agent claude-code --json
code-pact validate --json

# CI: --audit-strict は --base-ref <default-branch> と --json を併用（working tree が clean な CI では merge-base 起点で audit）
```

順序ガイダンスには `code-pact task runbook <id> --json` と `code-pact phase runbook <id> --json` が read-only で使えます。

起動ルール (エージェントの振る舞い):

- ユーザーがタスクを指定して実装を依頼したら (例: 「P1-T1 をやって」)、まずデフォルト minimal の `task prepare` から始める。
- デフォルトの minimal 出力は bounded な作業指示である: `data.task`、`data.next`、`data.more.command`。context pack を構築せず、重い取得も行わない。
- 明示的な budget flag (`--budget-bytes`, `--context-budget`, `--recommended-context-budget`) は `--detail minimal` を無視して `--detail full` を強制する。
- `next.type` (minimal) または `next_action.type` (full) を読む。可能な値は `start_task`, `continue_implementation`, `wait_for_dependencies`, `resolve_block`, `inspect_decision`, `noop_already_done`, `investigate_failure` である。
- next action が `wait_for_dependencies` の場合は実装しない — ブロックしている依存タスクを解消してから `task prepare` を再実行する。
- next action が `resolve_block` (manual block) の場合は `block.summary` (512 UTF-8 bytes 以内に bounded) の理由を解消してから `task prepare` を再実行する。
- next action が `inspect_decision` (`planned` 状態の `requires_decision` タスク) の場合、開始前に `next.command` の full-detail `task prepare` を実行して decision commitments を取得する。
- next action が `investigate_failure` の場合、`failure.summary` (512 UTF-8 bytes 以内に bounded) から原因を調査し、修正後に `task start` (または `task prepare`) を再実行する。
- `CONTEXT_OVER_BUDGET` のときは勝手にコンテキストを広げず、バジェット・タスク分割・達成可能な最小バイト数を報告する。
- `task finalize --write` は `task complete` が `done` イベントを記録した後にのみ実行する。

### What to verify first

実装前:

- `data.recommendation` は `task prepare` を `--detail full` または full detail を強制する明示的な budget flag で実行した場合にのみ存在します。実行プロファイルが必要な場合は `task prepare --detail full --json` または `recommend --json` から読みます。
- `recommend --json` の後は `data` を読みます。
- その recommendation object を、レポートではなく実行プロファイルとして扱ってください:
  - `tier` / `modelId` → 継続 / モデル切替 / runtime が **cannot switch model**（モデルを切り替えられない）場合は無視せず限界として報告する。
  - `effort` → 推論の深さ。`planningRequired` が true なら編集前に plan を書く。
  - `lifecycleMode` → ループを選ぶ: `full_loop`（prepare→start→complete→finalize）/ `decision_loop`（先に decision ADR を解決）/ `record_only`。
- `record_only` は**ループを軽くするだけで、検証を省くものではない**: プロジェクトの検証コマンドを省略せず実行し、その後 `task record-done --evidence "..."` で正直に記録する（evidence 必須・decision gate も honor）。
- タスクの `writes` field を読み、実際の意図を正確に反映させます。これにより `write_audit` advisory が有効な signal を出せます。

`task finalize --write` の前:

- 先に同じコマンドを `--json` のみ（`--write` なし）で実行し、`data.write_audit` を確認します。`outside_declared` や `declared_unused` が非空なら declared writes を先に修正します。
- ブランチレベルの audit には `--base-ref main` を渡します（`--json` 必須）。
- CI（working tree が clean / commit 済み）では、`--audit-strict` に `--base-ref <default-branch>` を併用してください。merge-base 起点で audit が走ります。`--base-ref` 無しだと未 commit の差分しか見えず、宣言された writes が working tree に現れていない task では `TASK_WRITES_AUDIT_DECLARED_UNUSED` で fail します: `task finalize <id> --audit-strict --write --json --base-ref origin/main`
- ローカルの pre-commit レビュー（未 commit の working tree を audit する用途）では `--base-ref` 不要: `task finalize <id> --audit-strict --write --json`

PR 境界:

- `code-pact validate --json` でプロジェクト整合性を確認。
- `code-pact plan lint --json` は advisory; `--strict` で warning が exit-relevant に昇格します（`--audit-strict` とは別 flag）。

### How to handle failures

- **dependency block** (`task prepare` から) — `next.type` (full detail では `next_action.type`) が `wait_for_dependencies` で、`blocked_by` に未完の上流タスク id が並びます。依存タスクを先に解消してから `task prepare` を再実行してください。
- **manual block** (`task prepare` から) — `next.type` が `resolve_block` で、`blocked_by` は省略されます。`block.summary` の理由 (512 UTF-8 bytes 以内に bounded) を解消してから `task prepare` を再実行してください。手動 `task block` の理由が解消されていれば、`code-pact task resume <task-id>` してから `task prepare` を再実行することもできます。
- **decision-required planned task** (`task prepare` から) — `next.type` が `inspect_decision` です。開始前に `next.command` の full-detail `task prepare` を実行して decision commitments を取得してください。
- **failed task prepare** (`task prepare` から) — `next.type` が `investigate_failure` です。`failure.summary` (512 UTF-8 bytes 以内に bounded) にある最後の verify/finalize 失敗の理由を調査し、修正後に `task start` (または `task prepare`) を再実行してください。
- **task complete の verification failure** (`task complete --json --detail agent` から) — `error.code` は `VERIFICATION_FAILED`（exit 1）。まず `error.cause_code` を確認: `COMMANDS_FAILED` → 失敗した検証コマンドを修正; `DECISION_REQUIRED` → `requires_decision` タスクに accepted な ADR が必要（作成・accept する）; `ABORTED` → 中断要因を解消してから retry。
- **standalone verify failure** (`verify --json --detail agent` から) — `error.cause_code` が保証されるのは cancellation (`ABORTED`) のみです。通常の失敗は `data.failure.kind` で分岐します: `command_failed` → 失敗したコマンドを修正; `timed_out` → timeout または hang したコマンドを調査; `decision_required` → required ADR を解決; `invalid_state` → `data.failure.check` と `data.failure.reason` を読む。
- `invalid_state` の代表的な check は `progress_event`（done event がない、または ledger consistency を確認すべき状態。通常は正規の `task complete` 経路を確認）と `task_status`（progress 上は完了しているが design task status が `done` ではない状態。`task finalize` 経路を確認）です。行動を選ぶ前に必ず `data.failure.reason` を読んでください。
- Agent detail の verification failure では `error.message` は意図的に短い固定文です。診断はこの順で行います: `data.failure.kind`, `data.failure.check`, `data.failure.reason`, `data.failure.fingerprint`（存在する場合）, `data.failure.stderr_excerpt`（存在する場合）, `data.failure.stdout_excerpt`（存在する場合）, `data.failure.evidence_available`, `data.failure.evidence_error`, `data.failure.retrieve_command`。
- `data.prior_local_signal` は、同じ failure fingerprint が bounded local store に保持されていることだけを示します（`exact_match_count`, `last_observed_at`）。過去の repair や仮説の内容は示さないため、推測しないでください。現在の会話または diff から同じ変更をそのまま再実行していると確認できる場合だけ、その再実行を避けます。`stopOnRepeatedFingerprint` が true なら、その停止 contract を先に優先してください。
- `fingerprint`、excerpt、Evidence field は optional で、通常は command-output failure にのみ存在します。`invalid_state`、decision、preflight、configuration failure で存在しないことを新しいエラー扱いしないでください。
- full evidence はデフォルトで取得しないでください。command-output failure で、excerpt だけでは修正判断に不足する場合に限り、`data.failure.retrieve_command` を使います。
- **missing context pack** — デフォルト minimal の `task prepare` は pack を生成・書き込みしません。pack を materialize する場合は、minimal 出力の `data.more.command` を使うか、`code-pact task prepare <task-id> --agent <name> --detail full --json` を実行してください。pack 本文だけ必要な場合は `code-pact task context <task-id> --agent <name>` を使ってください。
- **adapter drift** (`code-pact adapter doctor` / `code-pact adapter conformance <agent>` から) — インストール済み adapter ファイルが manifest と乖離している、または agent contract surface が不完全。`code-pact adapter upgrade <agent> --write` で再適用してください（手動編集を残したい場合は `--accept-modified`）。
- **`LOCK_HELD`** — 別の code-pact mutation が同プロジェクトで進行中。待って retry。`data.lock_holder` で保持者を確認できます。
- **`TASK_FINALIZE_NOT_ELIGIBLE`** — 先に `code-pact task complete <task-id>` を経由してください。derived state が進めば finalize 可能になります。
- **`WRITES_AUDIT_STRICT_FAILED`** — `--audit-strict` + 1 つ以上の `TASK_WRITES_AUDIT_*` warning。(a) declared writes を修正して audit が clean になるようにする、または (b) `--audit-strict` を外して deviation を記録する、のいずれか。この失敗パスでは design YAML は **mutate されません** (`applied: false`)。
- **`CONFIG_ERROR`** — 構造的な引数エラー（mutex flag、必須 positional の欠落、`--audit-strict` / `--base-ref` を `--json` なしで渡した、`--from-file` と `--stdin` 同時指定など）。コマンド surface を再確認してください。

- failure 後は既存の repair policy を読みます。既に `task prepare --detail full`（または full detail を強制する明示的な budget flag）の結果を持っている場合は `data.recommendation.repairPolicy` を使います。それ以外は `code-pact recommend --phase <p> --task <t> --agent <a> --json` を実行し、`data.repairPolicy` を読みます。
- `mode` が `disabled` なら自動 repair はしません。
- `mode` が `bounded` でも repair 対象は `command_failed` のみで、`maxRepairAttempts` が許す 1 回だけです。
- 最初の repair では `same_model_same_effort_same_context` を守り、model / effort / context を変更しません。
- `failure_delta` を使います: Failure Capsule と現在の差分だけです。context 拡張目的で `task prepare`、`task context`、repository-wide discovery を再実行しません。
- bounded repair で非対象の kind は terminal です: `timed_out`, `aborted`, `decision_required`, `unsafe_write`, `invalid_state`, `unknown`。
- full evidence は excerpt が不足する場合だけ取得し、デフォルト取得しません。
- `stopOnRepeatedFingerprint` が true で同一 fingerprint が再発したら停止します。
- `afterExhaustion` が `use_allowed_escalation` の場合、既存の `task prepare --detail full` 結果があれば `data.recommendation.allowedEscalation` を参照します。それ以外は `recommend --json` の `data.allowedEscalation` を参照します。

## Context directory

Context packs for this agent live under `.context/generic/`.

## プロジェクト固有の規約

> このセクションを編集して、実際のプロジェクト規約を記述してください。
> `design/constitution.md` と `design/rules/` が規約の source of truth です。

- `design/rules/coding-style.md` のコーディングスタイルに従う。