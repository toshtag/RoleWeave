# 逆プロキシの前提

この文書は日本語版を正本とする。

RoleWeave は、**前段に逆プロキシが居る**前提で production の設定を持つ。
`config.assume_ssl` と `config.force_ssl` がそれである。

この文書は、その前段に何を求めるかと、
**求めるものを満たさない場合に何が効かなくなるか**を書く。

## 逆プロキシに求めること

| 求めること | 満たさない場合 |
| --- | --- |
| `X-Forwarded-Proto` を設定する | HTTPS の判定が誤る。Cookie の `secure` が付かない |
| `X-Forwarded-For` を**上書きする**（追記ではなく、外から来た値を捨てる） | 利用者が IP を偽れる。下の「効かなくなるもの」を参照 |
| `Host` をそのまま渡す | 名前の検証（`ALLOWED_HOSTS`）が働かない |
| 稼働確認（`/up`）を通す | 監視が失敗する |

多くの逆プロキシは `X-Forwarded-For` を**追記**する。
追記であっても、`TRUSTED_PROXIES` に前段のアドレスを書けば、
Rails は「前段より外側で最初に現れるアドレス」を利用者の IP として扱う。

**書かない場合、Rails が既定で前段とみなすのは
ループバックと私用の範囲だけである。**
前段が公開の IP を持つ場合、その前段は信じられておらず、
利用者が書いた `X-Forwarded-For` がそのまま採用されうる。

## 設定

どちらも**書かなければ、いままでと同じ挙動**になる。

### `TRUSTED_PROXIES`

信じる前段のアドレス。IP アドレスまたは CIDR のカンマ区切り。

```
TRUSTED_PROXIES=10.0.0.0/8,203.0.113.10
```

Rails の既定（ループバックと私用の範囲）へ**足す**。既定を置き換えない。

IP アドレスでも CIDR でもない値を書くと、**起動の時点で失敗する**。
黙って読み飛ばすと、信じるつもりの前段が信じられていない状態のまま動く。

### `ALLOWED_HOSTS`

受け入れるホスト名。カンマ区切り。

```
ALLOWED_HOSTS=recruit.example.com,www.recruit.example.com
```

書くと、それ以外の `Host` を持つ要求は 403 になる。
稼働確認（`/up`）は名前の検証から除く。監視は名前ではなく IP で叩く構成がある。

## 設定しないと効かなくなるもの

`TRUSTED_PROXIES` を書かず、かつ前段が `X-Forwarded-For` を上書きしない場合、
**利用者が自分の IP を偽れる**。次の 2 つが影響を受ける。

- **レート制限**（[ADR 0044](../decisions/0044-rate-limiting.md)）。
  数える単位は IP である。header を変えるだけで数え直させられる。
  ログイン・登録・再設定の依頼・メッセージの上限が、実質的に効かない
- **監査ログ**（[ADR 0047](../decisions/0047-access-audit-log.md)、
  [ADR 0010](../decisions/0010-authentication-events.md)）。
  記録する IP が利用者の指定した値になる。
  漏えいの調査で「誰から来たか」の根拠にならない

`ALLOWED_HOSTS` を書かない場合、任意の `Host` を受け付ける。
DNS を書き換えられる位置に居る相手に対して、名前の検証が働かない。

## メールのリンク

メールの本文に載せる URL のホスト名は、要求の `Host` から取らない。
`config.action_mailer.default_url_options` が持つ固定の値を使う。

`config/environments/production.rb` の `host` を、
運用するホスト名へ書き換える。書き換えないと、
確認メールと再設定メールのリンクが `example.com` を指す。

## 判断の記録

[ADR 0062](../decisions/0062-reverse-proxy-assumptions.md)
