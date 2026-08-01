# アーキテクチャの概要

この文書は日本語版を正本とする。

判断の基準は [`principles.md`](principles.md)、
個別の判断は [`../decisions/`](../decisions/) にある（52 件）。
ここでは「何がどう組み合わさっているか」だけを書く。

## 構成

```
ブラウザー
   │ HTTPS（production は force_ssl）
   ▼
Rails 8.1（Puma）
   ├── Propshaft + Importmap（自前の資産だけ。外部の CDN を使わない）
   ├── Turbo / Stimulus
   ├── Active Storage（Disk。storage/ に置く）
   └── Solid Queue / Solid Cache / Solid Cable
   │
   ▼
PostgreSQL 18
```

外部のサービスに依存しない。SMTP だけが外へ出る。
自己ホストできることを前提に選んでいる。

## 経路の分け方

URL は必ず `/:locale` から始まる（[ADR 0001](../decisions/0001-locale-prefixed-routes.md)）。
表示言語の正本は URL であり、ブラウザーの設定でも Cookie でもない。

| 経路 | 誰が使うか | 入口の条件 |
| --- | --- | --- |
| `/ja/jobs` | 誰でも | なし |
| `/ja/profile/...` | 求職者 | ログイン + メールの確認 |
| `/ja/applications/:id/conversation` | 応募の当事者 | ログイン + 参加者であること |
| `/ja/organizations/:id/...` | 組織の所属者 | ログイン + 所属 |
| `/ja/operator/...` | 運営者 | ログイン + 運営者 |
| `/sitemap.xml`、`/robots.txt` | 検索エンジン | なし（ロケールを持たない） |

**権限がない場合は 404 を返す。**403 と分けない。
分けると「存在すること」だけが伝わる。

## 主要なモデル

```
User ─┬─ CandidateProfile ─┬─ WorkExperience / Education / Skill
      │                     ├─ DesiredCondition
      │                     ├─ 添付（resume / curriculum_vitae）
      │                     └─ JobApplication ─┬─ Conversation ─ Message ─ MessageRead
      │                                        ├─ ApplicationReview
      │                                        ├─ InterviewSchedule
      │                                        └─ JobApplicationEvent（応募が消えても残る）
      ├─ Membership ─ Organization ─ JobPosting
      ├─ Session / AuthenticationEvent
      └─ Notification
```

### 判定を 1 か所へ置く

同じ判断を複数の経路へ書かない。書き忘れた経路が、そのまま入口になる。

| 判定 | 置き場所 |
| --- | --- |
| 組織のデータを引く | `OrganizationScope#set_organization` |
| プロフィールが企業から見えるか | `CandidateProfile.visible_to(organization)` |
| 添付が企業から取れるか | `CandidateProfile#documents_visible_to?` |
| 会話を読めるか | `Conversation#participant?` |
| 選考を進められるか | `JobApplication#can_move_to?` |
| どれだけ残すか | `DataRetention::POLICIES` |
| 何をエクスポートするか | `ProfileExport::EXPORTED_COLUMNS` |

### 記録は消えても残す

削除で消える表と、削除されても残す表を分けている。

| 消えるもの | 残るもの |
| --- | --- |
| プロフィール、職歴、応募、メッセージ | 応募の記録（`JobApplicationEvent`） |
| アカウント | 所属の履歴、公開状態の履歴、認証の記録（匿名化） |
| 添付の実体 | 読んだ操作の記録（`AccessEvent`） |

残す側は、参照が消えても読めるように**表示名を写して持つ**。

## 横断して効いている仕組み

| 仕組み | 正本 |
| --- | --- |
| 日本語と英語（葉キーの一致をテストで固定） | [ADR 0001](../decisions/0001-locale-prefixed-routes.md) |
| 非公開を初期値とする | [ADR 0030](../decisions/0030-profile-visibility.md) |
| レート制限 | [ADR 0044](../decisions/0044-rate-limiting.md) |
| CSP・CSRF・セッション | [ADR 0045](../decisions/0045-content-security-policy.md) |
| 保持期限 | [ADR 0046](../decisions/0046-data-retention.md) |
| 監査ログ | [ADR 0047](../decisions/0047-access-audit-log.md) |
| 構造化ログ | [ADR 0048](../decisions/0048-structured-logging.md) |

## 判断を追う

ADR は番号順に積み上がっている。全部を読む必要はない。
知りたいことから引く。

| 知りたいこと | ADR |
| --- | --- |
| なぜ URL に言語が入るのか | 0001 |
| なぜ静的なエラー画面なのか | 0003 |
| パスワードとセッションの扱い | 0006、0007 |
| 組織と権限 | 0011〜0015 |
| 求人の審査と公開 | 0016〜0022 |
| 検索とページ分割 | 0021、0023、0024 |
| プロフィールと公開範囲 | 0026〜0031 |
| 持ち出しと削除 | 0032、0033 |
| 応募と選考 | 0034〜0040 |
| 連絡と通知 | 0041〜0043 |
| 安全と運用 | 0044〜0047 |
| 性能と観測 | 0048〜0050 |

## 意図的に持たないもの

| 持たないもの | 理由 |
| --- | --- |
| 生年月日・性別・顔写真 | 採用の判断に使ってはならない（ADR 0026） |
| 候補者の検索・一覧 | 「見せる」と「探される」は同じ同意ではない（ADR 0030） |
| 応募を経由しない連絡 | 探されない設計と食い違う（ADR 0041） |
| 外部のスクリプト・CDN | CSP を `self` から始められる（ADR 0045） |
| 商用の監視サービス | 自己ホストの前提と合わない（ADR 0048） |
