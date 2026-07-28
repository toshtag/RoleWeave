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
- 実装後は `verify` → `task complete` → `task finalize`（dry-run で `write_audit` を確認してから `--write`）の順で進める
- 実行していない検証を成功として記録・報告しない
- 検証コマンドを一時的に無効化して完了させない
