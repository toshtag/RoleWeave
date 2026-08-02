# 運営者として使う

この文書は日本語版を正本とする。

**運営者は「このサーバーを運用している人」である。**
組織の中の役割とは別の軸であり、画面からは付与できない。

デモデータでは `operator@example.invalid` が運営者である。

## 権限を与える・取り上げる

サーバーへ入れる人だけが行える。

```bash
docker compose run --rm app bin/rails "roleweave:operator:grant[you@example.com]"
```

```bash
docker compose run --rm app bin/rails "roleweave:operator:revoke[you@example.com]"
```

理由は [ADR 0015](../decisions/0015-operator-role.md) に書いた。
自己ホストの前提では、運営者はデータベースへ直接触れられる。
画面から付与できるようにしても、守りは増えない。

## できること

| やりたいこと | 経路 |
| --- | --- |
| すべての組織を見る | `/ja/operator/organizations` |
| 組織の所属者を見る・管理者を立てる | `/ja/operator/organizations/:id` |
| 配信に失敗した通知を見る・再送する | `/ja/operator/notification_deliveries` |
| 個人情報を読んだ操作の記録を見る | `/ja/operator/access_events` |

運営者でない利用者がこれらの経路を開くと、**404 が返る**。
403 と分けない。運営の経路が存在すること自体を伝えない。

## できないこと

- 他人のアカウントの削除
- 求人の内容の編集
- 応募の選考の操作
- 求職者のプロフィールの閲覧（公開範囲に従う。運営者でも例外にしない）

運営者は「組織が動かなくなった状態を直す」ための権限である。
すべてを見られる権限ではない。

## 運用でやること

| やること | 手順 |
| --- | --- |
| 前段の proxy の設定 | [逆プロキシの前提](../development/reverse-proxy.md) |
| 保持期限の適用 | [README](../../README.md) の「保持期限を適用する」 |
| バックアップ | [バックアップと復元](../development/backup-and-restore.md) |
| 配信の失敗の確認 | `/ja/operator/notification_deliveries` を定期的に見る |
| 性能の確認 | [負荷試験](../performance/load-test-results.md) の手順で測る |

**配信の失敗は自動で知らされない。**
メールが送れない状況で、メールで知らせることはできないためである
（[ADR 0043](../decisions/0043-notification-delivery-failures.md)）。
定期的に見に行く運用が要る。
