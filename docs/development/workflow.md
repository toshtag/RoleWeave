# 開発工程

タスクをどこで定義し、どこへ結果を記録するかを決める。

この文書は日本語版を正本とする。

## 正本の一覧

同じ情報を複数の場所へ置かない。

| 情報 | 正本 |
| --- | --- |
| 実行タスクと不具合 | GitHub Issues |
| 実装内容と検証結果 | GitHub Pull Requests と Git コミット |
| 恒久的な設計判断 | `docs/decisions/*.md`（ADR） |

進捗の台帳、Issue の状態を複製した status ファイル、
タスクごとの受け入れ計画文書を作業ツリーへ置かない。
過去の内容は Git 履歴から読める。

プロジェクト文書は `docs/` へ集約する。
完全検証は、撤去済みの旧 path（`design/` 配下）への参照を拒否する。

## Issue

実装タスクと不具合は GitHub Issues として日本語で登録する。
記載する項目は `.github/ISSUE_TEMPLATE/` が持つ。

**Issue は 1 つの確認可能な振る舞いに限定する。**

| 悪い例 | 良い例 |
| --- | --- |
| 認証を実装する | 重複するメールアドレスの登録を拒否する |
| 求人機能を作る | 権限のない担当者による求人編集を拒否する |
| セキュリティを強化する | 同一求人への二重応募を拒否する |

Issue に宣言した変更可能範囲（write scope）の外を変更しない。
広げる必要が出たときは、実装より先に Issue を更新する。

## Pull Request

- 1 Issue につき 1 PR とする
- タイトルは Conventional Commits の種別 + 日本語の要約
- 本文は日本語で書き、`.github/pull_request_template.md` に従う
- **実行していない検証を成功と書かない。**
  失敗や警告があるときは、コマンド、終了コード、原因、未解決範囲を省略せずに書く
- 無関係なリファクタリングを混ぜない
- 新規依存を勝手に追加しない。理由と代替案を先に Issue へ書く
- main へのマージは Squash merge とし、main 上では 1 タスク 1 コミットにする

## 検証

検証の入口は 2 つだけとする。

```bash
docker compose run --rm app bin/verify
```

```bash
bin/verify --full
```

各タスクで正の検証と負の検証の両方を行う。
スコープ外で見つけた問題は、そのタスクで直さず新しい Issue にする。

## セキュリティ検査

標準検証は、lint・autoload・test に加えて Brakeman と bundler-audit を実行する。
bundler-audit は advisory database を更新してから監査するため、外部通信と `git` が要る。
**更新に失敗したら検証も失敗する。**古い database へ黙って退避しない。

完全検証は、これらの呼び出しが削除・無効化・任意化されていないことを、
構造検査（`scripts/verify-security`）と隔離実行のプローブ
（`scripts/verify-security-self-test`）で確かめる。

守るべき点は 2 つ。

- `bin/verify` は各検査をトップレベルで直接実行する。
  共通関数へ委ねると、その関数を無処理にするだけで全検査を飛ばせる
- **`bin/verify` を変更するときは、`scripts/verify-security` の正規形を同じ PR で更新する**

判断の理由は、それぞれのスクリプトのヘッダーコメントにある。ここへ複製しない。

| 主題 | 正本 |
| --- | --- |
| 検査の呼び出しとバージョン固定 | `bin/verify`、`bin/brakeman`、`bin/bundler-audit` |
| 脆弱性の除外（`ignore` は空） | `config/bundler-audit.yml` |
| 秘密情報を持ち込まない契約 | `scripts/verify-p0`、`scripts/verify-p0-docker` |
| イメージへ入れないものの実測 | `scripts/verify-p0-docker` |

秘密情報の検査は path に基づく。
ファイルの内容に含まれる資格情報の検出も、Git 履歴全体の走査も行わない。
**検査していない範囲を、検査済みとして扱わない。**

## ADR

将来も参照する設計判断だけを `docs/decisions/*.md` へ残す。
実装の経緯や作業ログは ADR にしない。それらは PR と Git 履歴が持つ。

## AI Agent の扱い

AI Agent も人間の開発者と同じ工程を使う。

- タスクの定義は GitHub Issues、結果の記録は PR とコミットへ行う
- Agent 専用の進捗 CLI、イベント台帳、自動生成された制御面を導入しない
- 検証、コミット分割、言語、スコープの規約は人間と同じものへ従う
