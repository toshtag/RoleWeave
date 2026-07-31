---
tags: [quality, authorization, privacy, i18n, accessibility, verification]
applies_to: [architecture, feature, bugfix, refactor, test]
---

# 横断品質要件

機能を追加するフェーズで同時に満たす。後続のフェーズへ先送りしない。
`P10 Privacy Security and Operations` は、これらの初回実装フェーズではなく、
V1 全体に対する統合検証と不足の是正を行うフェーズである。

## authorization

追加したデータと操作の認可を同じフェーズで実装する。
後続のセキュリティフェーズへ先送りしない。

## tenant_isolation

組織に属するデータは、他組織から参照・変更できないことを
正の検証と負の検証で保証する。

## privacy

個人情報を追加するフェーズで、収集目的、公開範囲、保持、
削除または匿名化の扱いを決定する。
非公開を初期値とする。

## localization

利用者向け文字列は、同じフェーズで日本語と英語を実装する。

## accessibility

UI を追加するフェーズで、セマンティクス、ラベル、
キーボード操作を同時に検証する。

## verification

各タスクに正の検証と負の検証を設ける。
