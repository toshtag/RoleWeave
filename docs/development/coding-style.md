---
tags: [language, style, process]
applies_to: [architecture, feature, bugfix, refactor, mechanical_refactor, test, docs]
---

# コーディングスタイルルール

このファイルは、実装中に頻繁に参照する要点だけを置く。
正本は次の 3 ファイルとし、ここに規則を二重定義しない。

- [`docs/development/language-policy.md`](language-policy.md)
- [`docs/architecture/principles.md`](../architecture/principles.md)
- [`docs/development/workflow.md`](workflow.md)

## 言語

- コードコメント、テストの説明、コミット本文、PR、レビュー記録は日本語で書く
- クラス名、メソッド名、変数名、ファイル名、DB、URL、i18n キーは自然な英語で書く
- 日本語を直訳した不自然な英語を使わない

## コメント

- 処理内容を日本語で言い換えるだけのコメントを書かない
- 設計理由、制約、壊れやすい箇所、一見不自然な実装の必要性を説明するときに書く

## 構造

- Rails 標準の命名と構成を優先する
- 同じ責務を表すディレクトリを複数作らない
- 使う予定のないディレクトリを先回りして作らない

## 自動整形

- フォーマッターと Linter の出力を、手作業の好みより優先する
- 整形結果に不満がある場合は、個別に書き換えず設定側を変更する
- 整形だけの変更を、振る舞いを変える変更と同じコミットへ混ぜない
