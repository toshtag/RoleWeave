# 開発工程

このプロジェクトの開発タスクをどこで定義し、どこで進捗を追い、
どこへ結果を記録するかを明文化する。

この文書は日本語版を正本とする。

## 1. 正本の一覧

同じ情報を複数の場所で保持しない。それぞれの正本は次のとおりとする。

| 情報 | 正本 |
| --- | --- |
| 中長期計画（フェーズ順序・依存・完了条件） | [`docs/roadmap/index.yaml`](../roadmap/index.yaml) と `docs/roadmap/phases/*.yaml` |
| 実行タスクと不具合 | GitHub Issues |
| 実装内容と検証結果 | GitHub Pull Requests と Git コミット |
| 恒久的な設計判断 | `docs/decisions/*.md`（ADR） |

次を進捗や実行契約の正本として使用しない。

- ツール固有のイベント台帳や進捗データベース
- Issue の状態を複製した status ファイル
- タスクごとの巨大な受け入れ計画文書

過去の内容は Git 履歴で参照できるため、現在の作業ツリーへ複製を残さない。

プロジェクト文書は `docs/` へ集約する。
code-pact 時代に使用していた `design/` を、文書の正本として再導入しない。
Foundation 検証は、`design/` 配下の追跡ファイルと、削除済みの旧文書 path への参照を拒否する。

## 2. ロードマップ

`docs/roadmap/index.yaml` はフェーズの索引、`docs/roadmap/phases/*.yaml` は各フェーズの
目的、依存関係（`depends_on`）、対象範囲、非目標、完了条件、標準検証コマンドを保持する。

日々変化するタスク進捗やイベント履歴はロードマップへ書かない。
それらは GitHub Issues と Pull Requests で追う。

フェーズ YAML に置けるのはフェーズレベルの情報だけとする。

- フェーズの `status` は、フェーズ開始時と完了時だけ更新する
- Issue 単位の `planned` / `in_progress` / `done` をフェーズ YAML へ複製しない
- ブランチ名、担当者、Issue 間の依存、タスク単位の受け入れ条件は Issue へ置く
- 完了済みタスクの一覧は Git 履歴と Pull Requests で確認する。
  フェーズ YAML へ完了実績の要約を蓄積しない

タスクは Issue を先に作成してから着手する。
この工程自体を導入した移行タスク（P0-R1）は例外とし、遡及的なダミー Issue を作成しない。

## 3. Issue

実装タスクと不具合は GitHub Issues として日本語で登録する。
テンプレートは `.github/ISSUE_TEMPLATE/` に置く。

実装タスクの Issue には次を記載する。

- 目的
- 背景
- 変更可能範囲（write scope）
- 変更禁止範囲
- 受け入れ条件
- 正の検証
- 負の検証
- 非目標
- 依存 Issue

Issue は 1 つの確認可能な振る舞いに限定する。

Issue に宣言された変更可能範囲（write scope）以外のファイルを変更しない。
範囲を広げる必要が生じた場合は、実装より先に Issue 側で範囲を更新する。

悪い例:

- 認証を実装する
- 求人機能を作る
- セキュリティを強化する

良い例:

- 重複するメールアドレスの登録を拒否する
- 権限のない担当者による求人編集を拒否する
- 非公開求人を公開検索結果から除外する
- 同一求人への二重応募を拒否する

## 4. Pull Request

- 1 Issue につき 1 PR を原則とする
- PR タイトルは Conventional Commits の種別 + 日本語の要約とする
- PR 本文は日本語で書き、`.github/pull_request_template.md` に従う
- PR 本文には実測した検証結果と残課題を記録する
- 実行していない検証を成功と書かない。
  失敗や警告がある場合は、コマンド、終了コード、原因、未解決範囲を省略せずに書く
- 無関係なリファクタリングを同じ PR へ混ぜない
- 新規依存を勝手に追加しない。追加が必要な場合は理由と代替案を先に報告する
- main へのマージは原則 Squash merge とし、main 上では 1 タスク 1 コミットにまとめる

## 5. 検証

- 検証の入口は `docker compose run --rm app bin/verify`（標準検証）と
  `bin/verify --full`（完全検証）へ一本化する
- 各タスクで正の検証と負の検証の両方を実施する
- スコープ外で発見した問題は、そのタスクで実装せず、新しい Issue として登録する

## 6. セキュリティ検査

### 標準検証に含まれるもの

`docker compose run --rm app bin/verify` は、lint・autoload・test に加えて次を実行する。

- Brakeman による Rails コードの静的セキュリティ解析
- bundler-audit による依存関係の既知脆弱性検査
- 監査に先立つ advisory database の更新

呼び出しが削除・無効化・任意化されていないことは `scripts/verify-security` が検査し、
その検証器自体の退行は `scripts/verify-security-self-test` が検出する。
どちらも完全検証から実行する。

### ネットワーク要件

bundler-audit の advisory database 更新には、外部通信と `git` が必要となる。

- 更新に失敗した場合は標準検証も失敗する
- 取得済みの古い database へ黙ってフォールバックしない
- オフライン環境向けに成功扱いする経路は提供しない

検査したという事実を保証できない状態を、成功として記録しない。

### ignore ポリシー

`config/bundler-audit.yml` の `ignore` は空とする。

検出された脆弱性は、原則として依存関係の更新で解消する。
一時的な除外が必要になった場合は、別 Issue で advisory ID、影響を受けない根拠、
恒久対応の Issue、再確認期限、承認者を明記したうえで追加する。
説明のない除外と、実在しない placeholder は残さない。

### 秘密情報検査の範囲

完全検証は、次の path が Git 追跡対象になっていないことを検査する。

- `.env` および `.env.*`
- `config/master.key` と `config/**/*.key`
- `config/credentials.yml.enc` と `config/credentials/*.yml.enc`

判定するのは Git 追跡の有無であり、作業ツリー上の存在ではない。

これは path ベースの制御である。次は行わない。

- ファイル内容に含まれる API キーや資格情報の検出
- Git 履歴全体の走査
- 秘密情報検出ツール相当の網羅的な検査

検査していない範囲を、検査済みとして扱わない。

### バージョンの固定

Brakeman と bundler-audit のバージョンは `Gemfile.lock` で固定する。

- 新しいバージョンの公開そのものを検証の失敗条件にしない。
  `bin/brakeman` は `--ensure-latest` を付与しない
- バージョンの更新は、依存関係更新のタスクとして扱う

## 7. ADR

将来も参照する必要がある設計判断だけを `docs/decisions/*.md` に ADR として残す。
実装の経緯や作業ログは ADR にしない。それらは PR と Git 履歴が保持する。

`docs/decisions/` は最初の ADR が必要になった時点で作る。
空の将来用ディレクトリを先回りして作らない。

## 8. AI Agent の扱い

AI Agent も人間の開発者と同じ工程を使用する。

- タスクの定義は GitHub Issues、結果の記録は PR とコミットへ行う
- Agent 専用の進捗 CLI、イベント台帳、自動生成された制御面を導入しない
- 検証、コミット分割、言語、スコープの規約は人間と同じものへ従う
