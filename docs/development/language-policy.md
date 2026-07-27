# 開発言語・命名ポリシー

このプロジェクトでは、開発者と AI Agent が同じ判断基準で作業できるようにするため、
「どこで日本語を使い、どこで英語を使うか」を明文化する。

この文書は日本語版を正本とする。

## 1. 基本原則

- 人間が読んで議論するための文章は日本語で書く
- 機械が解釈する識別子は英語で書く
- 利用者に表示される文字列は日本語と英語の両方を提供する

この 3 つの区別を、以下で具体的に定める。

## 2. 日本語を使用するもの

- コードコメント
- テストケースの説明
- コミットメッセージの本文
- PR タイトルの要約部分
- PR 本文
- Issue
- タスク定義
- ADR および設計文書の本文
- 開発者向けの主要ドキュメント
- レビュー記録
- 検証結果

## 3. 英語を使用するもの

- クラス名
- モジュール名
- メソッド名
- 変数名
- データベース名
- テーブル名
- カラム名
- ファイル名
- ディレクトリ名
- URL
- API フィールド
- 構造化ログのキー
- 内部イベント名
- i18n キー
- Git ブランチ名
- Conventional Commits の種別

## 4. コメントの書き方

コメントは、処理内容を日本語で言い換えるために書かない。
コードを読めば分かることを繰り返すコメントは、保守されずに嘘になるため書かない。

コメントを書くのは、次のいずれかを説明する必要がある場合に限る。

- なぜその設計を選んだのか
- どのような制約があるのか
- どこに注意しなければ壊れるのか
- 一見不自然に見える実装が、なぜ必要なのか

書かない例

```ruby
# 求人を取得する
job_posting = JobPosting.find(params[:id])
```

書く例

```ruby
# 応募時点の条件を証跡として残すため、公開中の求人でも本文をコピーして保持する。
# 求人が後から編集されても、応募内容の意味が変わらないようにする。
snapshot = job_posting.attributes.slice(*SNAPSHOT_COLUMNS)
```

## 5. テストの説明

テストが何を保証しているのかを日本語で書く。
実装の呼び出し手順ではなく、期待する振る舞いを書く。

```ruby
test "メールアドレスが重複するアカウントを保存できない" do
  # ...
end
```

## 6. コミットメッセージ

Conventional Commits の種別は英語、要約と本文は日本語とする。

```text
feat: 求人の下書き作成を追加
fix: 非公開求人へのアクセスを拒否
test: 応募権限の回帰テストを追加
docs: 開発言語ポリシーを明文化
chore: Docker開発環境を追加
```

使用する種別は次のとおり。

| 種別 | 用途 |
| --- | --- |
| `feat` | 利用者から見た機能の追加 |
| `fix` | 不具合の修正 |
| `refactor` | 振る舞いを変えない内部改善 |
| `test` | テストの追加・修正 |
| `docs` | ドキュメントの追加・修正 |
| `chore` | ビルド、依存関係、開発環境 |
| `ci` | CI 設定 |
| `perf` | 性能改善 |

## 7. ブランチ名

ブランチ名は小文字 ASCII 英数字とハイフンを使用し、
フェーズ部とタスク部の区切りとしてスラッシュを 1 つ使用する。
大文字、アンダースコア、日本語、2 つ以上のスラッシュは使用しない。

`<phase>/<task>-<英語の要約>` の形式とし、次のパターンに一致させる。

```regex
^[a-z0-9]+/[a-z0-9]+(?:-[a-z0-9]+)*$
```

```text
p0/t1-project-policy
p0/t2-code-pact-setup
p0/t3-rails-bootstrap
p4/t2-job-draft-creation
```

## 8. PR

- PR タイトルは Conventional Commits の種別 + 日本語の要約とする
- PR 本文は日本語で書く
- 本文の構成は `.github/pull_request_template.md` に従う

```text
docs: 開発方針とロードマップを初期化
feat: 企業担当者による求人下書きの作成を追加
```

## 9. 利用者向け表示

- すべての利用者向け文字列は i18n を経由する
- 日本語と英語を初期段階から同等に扱う
- i18n キーは英語で、意味の階層を持たせて命名する
- 英語版だけに存在する機能説明や、日本語版だけに存在する約束を作らない

```yaml
job_postings:
  show:
    apply_button: 応募する
```

## 10. OSS ドキュメント

- `README.md` は日本語、`README.en.md` は英語とする
- 相互にリンクする
- 設計上の正本は日本語版とする
- 公開仕様や利用者向け説明について、日本語と英語の不一致を許容しない

日本語と英語の両方を提供する範囲は次のとおり。

- 利用者向け UI
- 公開仕様
- セットアップ手順
- 操作文書

日本語を正本とし、英訳を必須としない範囲は次のとおり。

- 内部設計文書
- ADR
- タスク定義
- レビュー記録
- 検証結果

英訳を必須としない範囲であっても、英語版だけに存在する約束を作ってはならない。

## 11. 禁止事項

- 過去のシステムに由来する固有名詞を使用しない
- 意味が通じない造語を作らない
- 日本語を機械的に直訳した不自然な英語を使用しない
- `RoleWeave` 以外のブランド名を新しく作らない
- 実在する人物、会社、求人情報をデモデータに使用しない

## 12. プロジェクト名称 `RoleWeave` の使用規則

- 正式なプロジェクト名および製品名は `RoleWeave` とする
- Rails のアプリケーション設定クラスは `RoleWeave::Application` とする
- `RoleWeave` を業務モデルや業務モジュールの共通親名前空間にしない
- 業務モデルと業務モジュールは、トップレベルの自然な英語名とする
- 業務クラス、ファイル、ディレクトリへ `RoleWeave` を接頭辞として付けない
- `RoleWeave` 以外のブランド名を新しく作らない
- 内部の業務用語には、一般的で自然な英語を使用する

`RoleWeave` は Rails アプリケーション設定の名前空間に限定する。
業務定数をその配下へ置くと、ブランド名を含む物理パス
（`app/models/role_weave/...`）または独自の autoload 設定が必要になり、
「Rails 標準構成を維持する」という原則と両立しないため採用しない。

許容例

```text
RoleWeave::Application
Account
JobApplication
ApplicationStage
JobPostings::Publish
JobApplications::Submit
Hiring::AdvanceApplication
```

禁止例

```text
RoleWeave::JobApplication
RoleWeave::JobPostings::Publish
RoleWeaveJobApplication
RoleWeaveAccount
role_weave_job_postings
app/models/role_weave/job_application.rb
```

`RoleWeave::Application` は Rails のアプリケーション設定クラスであり、
応募を表す業務モデルではない。応募は `JobApplication` とし、
`ApplicationRecord` および `ApplicationController` との意味上の混同を避ける。

## 13. 共通語彙

内部の一般名称には、採用領域で広く通用する次の語彙を使用する。
独自の言い換えを増やさない。
日本語の語をそのまま英語化した造語を作らない。

```text
Account
Organization
Membership
JobPosting
CandidateProfile
JobApplication
ApplicationStage
Conversation
Message
Notification
TalentPool
SourcingCampaign
Integration
AuditEvent
```
