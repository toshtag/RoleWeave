# セキュリティ上の問題の報告

この文書は日本語版を正本とする。
An English summary follows the Japanese text.

## 報告の方法

セキュリティ上の問題を見つけた場合は、**公開の Issue を作らずに**
GitHub の [Security Advisories](https://github.com/toshtag/RoleWeave/security/advisories/new)
から非公開で報告してください。

公開の Issue で報告すると、修正が用意される前に内容が広まります。
自己ホストで動かしている利用者は、その間、直す手立てを持ちません。

## 報告に含めてほしいこと

- 何が起きるか（読めてはいけない情報が読める、権限のない操作ができる、など）
- 再現の手順
- 影響を受ける範囲（分かる場合）
- 確認したバージョン（コミットの識別子）

## 受け取った後の扱い

このプロジェクトは個人が開発している OSS であり、
24 時間の監視体制はありません。次のとおりに扱います。

1. 受け取ったことを、**7 日以内**に返信します
2. 内容を確認し、影響を判断します
3. 修正を用意し、公開します
4. 報告者の希望に応じて、公開時に謝辞を記載します

期日を約束できるのは 1 の返信までです。
修正までの期間は、内容と影響によって変わります。

## 対象になるもの

このリポジトリのコードと設定が対象です。

次は対象外です。

- 自己ホストの環境の設定（SMTP、TLS、リバースプロキシ、データベースの権限）
- 依存しているソフトウェア自体の脆弱性（そちらへ報告してください）
- 運営者（サーバーの管理者）による操作。
  自己ホストの前提であり、脅威モデルの想定に含めていません
  （[`docs/security/threat-model.md`](docs/security/threat-model.md)）

## 既知の受け入れているリスク

対策していないことを、あらかじめ
[`docs/security/threat-model.md`](docs/security/threat-model.md) に書いています。
そこに書かれているものは既知です。報告の前に確認してください。

---

## English

Please report security issues **privately** through
[GitHub Security Advisories](https://github.com/toshtag/RoleWeave/security/advisories/new),
not through public issues.

Include what happens, how to reproduce it, the affected scope if known,
and the commit you tested.

This is an OSS project maintained by an individual. There is no 24/7 on-call.
We reply within **7 days**, then assess, fix, and publish.
Only the reply time is a commitment; the time to a fix depends on the issue.

Self-hosted environment settings, upstream dependencies, and actions by the
server operator are out of scope. Risks we knowingly accept are listed in
[`docs/security/threat-model.md`](docs/security/threat-model.md).
