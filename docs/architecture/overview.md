# アーキテクチャの概要

この文書は日本語版を正本とする。

判断の基準は [`principles.md`](principles.md)、
個別の判断は [`../decisions/`](../decisions/) にある（63 件）。
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

外部のサービスに依存しない。自己ホストできることを前提に選んでいる。

外へ出る通信は 2 つだけである。

- SMTP（メールの送信）
- Webhook の配信。**送り先は利用者が登録する。**
  こちらは送る仕組みだけを持ち、特定のサービスへは依存しない。
  内部の宛先へ向けられないよう、宛先の判定を 1 か所に置いている（ADR 0060）

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
      │                     ├─ SavedJobPosting / SavedSearch
      │                     ├─ Scout（受け取ったもの）/ ScoutBlock（組織ごとの配信停止）
      │                     ├─ TalentPoolMember
      │                     └─ JobApplication ─┬─ Conversation ─ Message ─ MessageRead
      │                                        ├─ ApplicationReview
      │                                        ├─ InterviewSchedule
      │                                        └─ JobApplicationEvent（応募が消えても残る）
      ├─ Membership ─ Organization ─┬─ JobPosting
      │                             ├─ TalentPool ─ TalentPoolMember
      │                             ├─ Scout / ScoutTemplate / ScoutBlock
      │                             ├─ Webhook ─ WebhookDelivery
      │                             └─ IntegrationRun（CSV の実行結果）
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
| 探せる候補者か | `CandidateProfile.searchable` |
| Webhook を送ってよい宛先か | `WebhookDestination` |

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
| 前段の proxy の前提 | [ADR 0062](../decisions/0062-reverse-proxy-assumptions.md) |
| 受け取る入力の大きさの上限 | [ADR 0063](../decisions/0063-request-size-limits.md) |

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
| デモと版の付け方 | 0051、0053 |
| 保存と候補者の発掘 | 0054、0055 |
| スカウト | 0056 |
| 外部連携（Webhook・CSV） | 0057、0058、0060、0061 |
| v1 以降の判断の進め方 | 0059 |
| 前段の proxy と入力の大きさ | 0062、0063 |

## 意図的に持たないもの

| 持たないもの | 理由 |
| --- | --- |
| 生年月日・性別・顔写真 | 採用の判断に使ってはならない（ADR 0026） |
| 許可のない候補者の検索・一覧 | 「見せる」と「探される」は同じ同意ではない。**許可した候補者だけを対象にする**（ADR 0030、ADR 0055） |
| 応募を経由しない双方向のやり取り | スカウトは 1 組織から 1 通だけで、返信の経路を持たない。続きは応募の会話で行う（ADR 0041、ADR 0056） |
| 候補者・応募者の CSV | 一括で持ち出せる形にしない（ADR 0058） |
| Webhook への個人情報 | 送った先には公開範囲も保持期限も効かない（ADR 0057） |
| 個別サービス向けの連携実装 | 商用 SDK へ直接依存しない（P14 の非目標） |
| 外部のスクリプト・CDN | CSP を `self` から始められる（ADR 0045） |
| 商用の監視サービス | 自己ホストの前提と合わない（ADR 0048） |
