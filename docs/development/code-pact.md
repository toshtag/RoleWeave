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

実装したあと、検証と完了記録を行う。

```bash
npm exec -- code-pact verify --phase <PHASE_ID> --task <TASK_ID>
```

```bash
npm exec -- code-pact task complete <TASK_ID> --agent generic
```

finalize は、まず dry-run で結果と `write_audit` を確認してから書き込む。

```bash
npm exec -- code-pact task finalize <TASK_ID> --json
```

```bash
npm exec -- code-pact task finalize <TASK_ID> --write --json
```

dry-run の結果を確認せずに `--write` を実行しない。

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
  code-pact 上の実行履歴を持たないため、`.code-pact/state/` に偽のイベント履歴を作らない。
  設計上の状態としてのみ `done` を維持する。
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

現時点で確認している生成物の注意点は次のとおり。

- 「プロジェクト固有の規約」節が `design/rules/coding-style.md` を参照しているが、
  これは `code-pact init` のサンプル規約であり、このプロジェクトでは採用していない。
  実際の規約は `design/constitution.md` と `design/rules/` 配下の 4 ファイルである。
- コマンド例の `--agent claude-code` は code-pact 側の汎用例である。
  このプロジェクトでは `--agent generic` を指定する。

### コンテキストパック

`generic` アダプターのコンテキストパックは `.context/generic/` へ書き出される。
`.context/` は `code-pact init` が `.gitignore` へ追加するため、リポジトリへコミットしない。
必要になった時点で `task prepare --detail full` または `task context` で生成する。

## 6. 制御面の構成

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
└── rules/                    タスク実行時のルール
```

フェーズとタスクの状態の正本は `design/` 配下に一本化する。
`docs/` 配下に状態付きの別ロードマップを作らない。
