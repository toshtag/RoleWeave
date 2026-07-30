---
tags: [process, code-pact, agent]
applies_to: [architecture, feature, bugfix, refactor, mechanical_refactor, test, docs]
---

# code-pact 実行ルール

運用手順の詳細は [`docs/development/code-pact.md`](../../docs/development/code-pact.md) を正本とする。
このファイルは、タスク実行時に必ず守る要点だけを示す。

## 実行方法

- code-pact はリポジトリへ固定したローカル版を使用する。グローバルインストールを使わない
- コマンドは必ず `npm exec -- code-pact ...` 経由で実行する
- 使用する Agent 名は `generic` のみとする。`--agent generic` を指定する
- `--agent claude-code`、`--agent codex`、`--agent cursor`、`--agent gemini-cli` を指定しない

## 生成物の扱い

- `docs/code-pact/agent-instructions.md` は code-pact が管理する参考文書である
- 管理対象の生成物を直接編集しない。編集すると `adapter doctor` が `ADAPTER_FILE_DRIFT` を報告する
- 生成物中の汎用例（`--agent claude-code` などのコマンド例）とプロジェクトの規約が矛盾する場合は、
  `design/constitution.md` と `design/rules/` を優先する

## ライフサイクル

- P0-T3 以降は、実装前に `task prepare` と `task start` を実行する
- 実装後は `task complete` → `task finalize`（dry-run で `write_audit` を確認してから `--write`）
  → `verify` の順で進める
- タスクを指定した `verify` は finalize より前に実行しない。
  `verify` は done イベントとフェーズ YAML の `status` の両方を確認するが、
  `status` を `done` へ更新するのは `task finalize --write` である。
  順序を誤ると `task_status` で必ず失敗し、フェーズ検証コマンドの実行時間が無駄になる
- 実行していない検証を成功として記録・報告しない
- 検証コマンドを一時的に無効化して完了させない

## タスク契約のロック

`task start` は、タスク契約（`description` / `reads` / `writes` / `depends_on`）と
フェーズの `verification.commands` をロックする。

- `reads`、`writes`、`acceptance_refs`、依存関係、検証コマンドは `task start` の前に確定する
- 必要な制御面の変更を先にコミットし、作業ツリーを clean にしてから `task start` する
  （`task start` は作業ツリーが clean でないと契約をロックできない）
- start 後にこれらを変更すると `TASK_CONTRACT_DRIFT` が発生し、`task complete` が失敗する
- drift を避けるために検証を弱めない。契約を正しく直してからやり直す

## finalize

- `task finalize` は dry-run と `--write` の両方で `--audit-strict` を指定する
- `write_audit` の `outside_declared` と `declared_unused` を空にしてから `--write` する
- 進捗イベント（`.code-pact/state/events/**`）は write audit の対象外であるため、
  `writes` へ宣言しない。宣言すると `TASK_WRITES_AUDIT_DECLARED_UNUSED` になる
- `design/roadmap.yaml`、`design/phases/*.yaml`、`.code-pact/**` は Code Pact の保護パスである。
  実行中のタスクがこれらを `writes` へ宣言していると、strict な `plan lint` が
  `TASK_WRITES_PROTECTED_PATH` を終了コードへ反映するため、
  フェーズ検証に strict lint を含むフェーズでは `task complete` できない。
  制御面自体を変更するタスクは、その変更を `task start` 前のコミットで済ませる
