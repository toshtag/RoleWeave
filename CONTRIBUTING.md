# 開発に参加する

この文書は日本語版を正本とする。
An English summary follows the Japanese text.

## はじめに

RoleWeave は個人が開発している OSS です。
Issue も Pull Request も歓迎します。返信までに時間がかかることがあります。

**セキュリティ上の問題は、公開の Issue ではなく
[`SECURITY.md`](SECURITY.md) の手順で報告してください。**

## 進め方

1 つの Issue につき、1 つの成果と 1 つの Pull Request を原則としています。

```
Issue を作る → ブランチを切る（pN/tM-slug）→ 細かくコミット →
Pull Request を作る → 検証の結果を書く → squash merge
```

詳細は [`docs/development/workflow.md`](docs/development/workflow.md) にあります。

## 変更の前に

- 何を変えるかを Issue に書いてください。
  変更可能範囲と変更禁止範囲を明示すると、レビューが早く終わります
- 設計の判断を伴う変更は、ADR（`docs/decisions/`）を書いてください。
  「なぜそうしたか」と「なぜ別の案を採らなかったか」の両方を書きます
- 依存を足す変更は、**足す前に**理由と代替案を Issue へ書いてください

## 検証

Pull Request には、次の 3 つの結果を書いてください。

```bash
docker compose run --rm app bin/verify
```

```bash
bin/verify --full
```

**負の検証**も行ってください。
実装を一時的に壊し、テストが実際に落ちることを確かめます。
落ちなかった場合は、そのことを PR へ書き、テストを足してください。

このリポジトリでは、負の検証で 10 件以上の見落としが見つかっています。
「テストがある」ことと「テストが守っている」ことは別です。

## コードの書き方

- 識別子は英語、利用者向けの文言は日本語と英語
  （[`docs/development/language-policy.md`](docs/development/language-policy.md)）
- コメントは**なぜそうしたか**を書きます。何をしているかはコードが示します
- 判定を複数の場所へ書かないでください。書き忘れた場所が入口になります
- 詳細は [`docs/development/coding-style.md`](docs/development/coding-style.md)

## 文言を足すとき

日本語と英語の両方を、同じ変更で足してください。
葉キーの一致はテストで固定されています。片方だけではテストが落ちます。

## データを足すとき

表を足すと、次のテストが落ちます。落ちたら、それぞれで判断を書いてください。

| テスト | 何を求めるか |
| --- | --- |
| `organization_scoping_test` | 組織を持つなら必須にし、削除時に消す（例外は理由を書く） |
| `data_retention_test` | どれだけ残すか、または対象にしない理由 |
| `profile_export_test` | 本人へ出すか、出さない理由 |

**落ちるのは仕組みが働いている証拠です。**回避せずに、判断を書いてください。

## ライセンス

貢献したコードは、このリポジトリのライセンスの下で公開されます。

---

## English

RoleWeave is an OSS project maintained by an individual. Issues and pull
requests are welcome; replies may take time.

Report security issues privately via [`SECURITY.md`](SECURITY.md), not public issues.

One issue, one outcome, one pull request. Include the results of
`bin/verify` and `bin/verify --full` in every pull request, plus a
**negative verification**: break the implementation on purpose and confirm the
tests fail. If they do not, say so and add the missing test.

Identifiers are in English; user-facing text ships in both Japanese and English
in the same change. Comments explain *why*, not *what*.

Adding a table will fail three structural tests on purpose. Do not work around
them — record the decision they ask for.
