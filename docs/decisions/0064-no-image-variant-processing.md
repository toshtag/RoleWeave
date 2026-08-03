# ADR 0064: Active Storage の variant は生成しない

- 状態: 採用
- 決定日: 2026-08-03

この文書は日本語版を正本とする。

## 背景

`image_processing` は Rails の生成物として最初から `Gemfile` に入っていた。
`config.active_storage.variant_processor` も既定の `:vips` のままである。

一方で、このリポジトリは variant を一度も生成していない。

- 添付は `CandidateProfile` の `resume` と `curriculum_vitae` だけで、
  どちらも職務経歴書の書類である
- `variant` を呼ぶコードが存在しない
- [ADR 0046](0046-data-retention.md) に基づく保持期限の一覧
  （`app/models/data_retention.rb`）は、`active_storage_variant_records` について
  「変換した画像を作っていない」と書いている

つまり「variant を作れる」という前提だけが、設定と依存に残っていた。

この状態の費用が、依存の更新で表面化した。

`image_processing` 2.0.0 は `mini_magick` と `ruby-vips` を soft dependency へ移し、
backend が無いときの `LoadError` のメッセージを変えた。
Rails 8.1 の Active Storage は初期化時に `variant_transformer` を解決し、
そこで出た `LoadError` を握り潰すのは、メッセージが `/libvips/` か
`/image_processing/` に一致する場合だけである（activestorage の `engine.rb`）。
2.0 のメッセージは `ruby-vips` を名指しするため、どちらにも一致せず、再送出される。

結果として、`image_processing` 2.0 を採ると、libvips が無い環境では
アプリケーションの起動そのものが落ちる。
開発イメージには libvips があるが、ホストと CI runner にはない。
`bin/verify --full` と `bin/ci` はホスト側で Rails を起動する。

1.14.0 までこれが表に出なかったのは、backend が必須依存だったため、
メッセージが libvips 由来になり `/libvips/` に一致して握り潰されていたからである。
「動いていた」のではなく、「落ちていたが黙っていた」に近い。

## 決定

- `config.active_storage.variant_processor` を `:disabled` とする
- `image_processing` を `Gemfile` から外す。backend（`mini_magick`、`ruby-vips`）も宣言しない
- variant を生成しない状態を、`test/configuration/` の契約テストで固定する
- 画像の変換が必要になったときは、その機能の Issue で
  依存・設定・実行環境の前提をまとめて足す

## 理由

**使っていない機能のために、実行環境の前提を増やさない。**

`image_processing` 2.0 を採るなら、ホストと CI runner の両方へ libvips を入れ、
その前提を貢献者の手引きへ書く必要がある。
一度も呼ばれていないコード経路のために、環境構築の難度を上げる取引は成り立たない。

**持っていない機能は、持っていないと書く。**

`variant_processor` が `:vips` のままだと、設定を読んだ人は
「variant を作る構成である」と判断する。実際には作っていない。
`:disabled` は、実装と設定を一致させる表明である。

**版を上げない選択は採らない。**

`image_processing` を 1.14.0 へ据え置くこともできるが、
それは「使っていない依存を、更新できないまま抱え続ける」ことを意味する。
依存の遅れは時間とともに一度に飛ぶ距離が伸びる。
使っていないなら、抱えないほうがよい。

**将来の再導入は難しくない。**

variant が必要になったときに足すのは、`Gemfile` の 2 行と設定 1 行、
そして実行環境への libvips の導入である。
そのときは「何のために変換するのか」が決まっているため、
必要な前提も一緒に決められる。
いま前提だけを先に持っておく理由はない。

## 影響

- 画像の variant を生成しようとすると、`NullTransformer` が選ばれ、変換されない。
  現時点でそれを呼ぶコードはない
- `active_storage_variant_records` は空のままである。
  [ADR 0046](0046-data-retention.md) の保持期限の判断は変わらない
- `Gemfile.lock` から `image_processing`、`mini_magick`、`ruby-vips` が消える
- ホストと CI runner に libvips を導入する必要がなくなる

## 扱わないこと

開発イメージの libvips と、`scripts/verify-p0-docker` が要求する
libvips 8.13 以上の契約は、この ADR では変更しない。

variant を作らないなら libvips も不要になるが、
Active Storage の解析器の経路と、CVE-2026-66066 への対策として置いた
検証契約の両方に触れる判断になる。別の変更として扱う。

libvips を残したままでも、gem を宣言していない限り Ruby 側から使われることはない。

**追記（2026-08-03）**: この範囲は #214 で扱った。
開発イメージから libvips を外し、完全検証の版の下限の検査を不在の検査へ置き換えた。
上の決定と理由は当時のまま残す。
