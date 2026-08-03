# ADR 0065: 使わない Rails のフレームワークを読み込まない

- 状態: 採用
- 決定日: 2026-08-03

この文書は日本語版を正本とする。

## 背景

`config/application.rb` は Rails の生成物のまま `require "rails/all"` を書いていた。
`rails/all` は 10 個の railtie をまとめて読み込む。

このうち 3 つは、このアプリケーションで一度も使われていない。

| フレームワーク | 確認した内容 |
| --- | --- |
| Action Cable | `app/channels/` が無い。`*_channel.rb` 0 件。`ActionCable` / `broadcast` / `stream_from` / `stream_for` の参照 0 件。`config/routes.rb` に mount なし |
| Action Text | `has_rich_text` / `rich_text_area` / `ActionText` の参照 0 件。`db/schema.rb` に `action_text_*` の表なし |
| Action Mailbox | `app/mailboxes/` が無い。`ApplicationMailbox` / `ActionMailbox` の参照 0 件。`db/schema.rb` に `action_mailbox_*` の表なし |

読み込むだけで、起動のたびに railtie の初期化、autoload path の登録、
routes への追加が走る。

Action Cable については、さらに次を抱えていた。

- `Gemfile` の `solid_cable`
- `config/cable.yml`
- `db/cable_schema.rb`
- `config/database.yml` の production の `cable` 定義。
  `role_weave_production_cable` という**運用対象のデータベース 1 つ**

WebSocket を 1 か所も使わないアプリケーションのために、
本番環境がデータベースを 1 つ余分に持ち、
その作成・接続・バックアップ・監視の対象に含めていた。

これは [ADR 0064](0064-no-image-variant-processing.md) と同じ形である。
Rails の生成物として入ったまま、誰も選んでいない。

## 決定

- `require "rails/all"` をやめ、使うものだけを明示的に `require` する
- Action Cable、Action Text、Action Mailbox を読み込まない
- `solid_cable` を `Gemfile` から外し、`config/cable.yml` と
  `db/cable_schema.rb` を削除し、production の cable データベースを廃止する
- 読み込まない状態を `test/configuration/` の契約テストで固定する
- WebSocket・リッチテキスト・受信メールが必要になったときは、
  その機能の Issue で、フレームワーク・依存・データベースの前提をまとめて足す

読み込むものは次の 7 つとする。

```
active_record/railtie    Active Record
active_storage/engine    添付（職務経歴書の PDF）
action_controller/railtie
action_view/railtie
action_mailer/railtie    通知・招待・確認のメール
active_job/railtie       Solid Queue で動かすジョブ
rails/test_unit/railtie  テスト
```

## 理由

**`rails/all` は「全部いる」という表明ではない。**

生成時の既定であり、選択ではない。
`require` の一覧を明示すると、何を使っているかがそこに書かれる。
使わなくなったものを消し忘れれば、一覧が実装とずれて目に付く。

**本番の運用対象を、使っていない機能のために増やさない。**

cable データベースは、作る・繋ぐ・バックアップする・監視する対象である。
1 つ増えるたびに、手順書と障害時の確認箇所が増える。
一度も書き込まれない表のために払う費用ではない。

**`rails/all` は `LoadError` を握り潰す。**

`rails/all` は各 railtie の `require` を `rescue LoadError` で囲んでいる。
gem を外しても静かに読み込まれなくなるだけで、何も知らせない。
明示的な `require` にすると、外したものは `LoadError` で止まる。
消したつもりのものが残る、残したつもりのものが消える、のどちらも起きにくくなる。

**再導入は難しくない。**

必要になったときに足すのは `require` 1 行と、
そのフレームワークが要求する設定・依存・データベースである。
そのときは「何のために使うのか」が決まっているため、前提も一緒に決められる。
いま前提だけを先に持っておく理由はない。

## 影響

- Action Cable、Action Text、Action Mailbox の定数は存在しなくなる。
  現時点でそれらを参照するコードはない
- `config/database.yml` の production から `cable` が消える。
  `role_weave_production_cable` は不要になる
- `solid_cable` が `Gemfile.lock` から消える
- `solid_queue`（ジョブ）と `solid_cache`（`rate_limit` の store）は変更しない

## 扱わないこと

`solid_queue` と `solid_cache` は使われており、この ADR の対象外とする。

`solid_cache` は `Rails.cache` を直接呼ぶ箇所が無いため未使用に見えるが、
Rails 8 の `rate_limit` が既定で `config.cache_store` を使う。
production の `cache_store` は `:solid_cache_store` であり、
外すと本番のレート制限がプロセスローカルになる（[ADR 0044](0044-rate-limiting.md)）。
