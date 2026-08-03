# ADR 0068: Stimulus を持たない

- 状態: 採用
- 決定日: 2026-08-03

この文書は日本語版を正本とする。

## 背景

`stimulus-rails` は Rails の生成物として最初から `Gemfile` に入っていた。
`config/importmap.rb` は `@hotwired/stimulus` と `@hotwired/stimulus-loading` を
pin し、`app/javascript/application.js` は `import "controllers"` を書いている。

一方で、このリポジトリに Stimulus の controller は 1 つも無い。

| 確認した内容 | 結果 |
| --- | --- |
| `*_controller.js` | 0 件 |
| `data-controller` / `data-action` / `data-*-target` の参照 | 0 件（`app/views/`、`public/`） |
| `app/javascript/controllers/` の中身 | 生成物の `application.js` と `index.js` の 2 つだけ |

`index.js` は `eagerLoadControllersFrom("controllers", application)` を呼ぶ。
走査する対象は空のディレクトリである。

それでも `javascript_importmap_tags` は、すべての画面で次を配る。

| 資産 | 大きさ | 実際の用途 |
| --- | --- | --- |
| `stimulus.min.js` | 45,640 バイト | 使う controller が無い |
| `stimulus-loading.js` | 3,315 バイト | 空のディレクトリを走査する |

ブラウザーは約 49 キロバイトを取得し、`Application.start()` を実行し、
`window.Stimulus` を置き、MutationObserver を張ってから、何も見つけない。

これは [ADR 0064](0064-no-image-variant-processing.md)、
[ADR 0065](0065-no-unused-rails-frameworks.md)、
[ADR 0066](0066-no-container-entrypoint.md) と同じ形である。
Rails の生成物として入ったまま、誰も選んでいない。

## 決定

- `Gemfile` から `stimulus-rails` を外す
- `config/importmap.rb` から `@hotwired/stimulus`、`@hotwired/stimulus-loading`、
  `pin_all_from "app/javascript/controllers"` を外す
- `app/javascript/application.js` から `import "controllers"` を外す
- `app/javascript/controllers/` を削除する
- `stimulus-rails` が依存に無いことを、`dependency_declaration_test` で固定する
- importmap が配る項目の一覧を、テストで固定する
- **Turbo は残す。**`turbo-rails`、`importmap-rails`、`propshaft` は変更しない
- JavaScript の振る舞いが必要になったときは、その機能の Issue で、
  何に使うかと合わせて依存を足す

## 理由

**呼ばれないものを落とす基準を、ここにも当てる。**

このリポジトリは同じ判断を繰り返している。

| | 落としたもの |
| --- | --- |
| [ADR 0064](0064-no-image-variant-processing.md) | 画像処理の依存と libvips |
| [ADR 0065](0065-no-unused-rails-frameworks.md) | 使わない Rails のフレームワークと cable データベース |
| [ADR 0066](0066-no-container-entrypoint.md) | 何もしない ENTRYPOINT の層 |
| [#217](https://github.com/toshtag/RoleWeave/issues/216) | 一度も呼ばれていない gem |

理由はいずれも同じで、入れておくと、更新も追跡も、
何のために続けているのか分からないまま残る。

**ここでは、費用を利用者が払っている。**

これまで落としてきたものは、開発環境・CI・イメージの費用だった。
Stimulus は違う。約 49 キロバイトの取得と実行は、
画面を開く人の回線と端末で起きる。
一度も使わない機能のために、それを全画面で続けていた。

**Turbo との違いを、依存の一覧に残す。**

`turbo-rails` と `stimulus-rails` は生成物として一緒に入る。
片方は使っていて、片方は使っていない。
一覧が「Hotwire 一式」のままだと、この違いはどこにも書かれない。
外して初めて、残したものが選ばれたものになる。

**「あとで JavaScript を書くかもしれない」は、いま持つ理由にならない。**

戻すのは `Gemfile` 1 行と pin 2 行である。
そのときは「何に使うか」が決まっているため、
CSP（[ADR 0045](0045-content-security-policy.md)）との関係も一緒に判断できる。

いま空の `controllers/` を持っていると、次に何かを足す人は
「ここに書けばよい」と判断する。判断の機会がそこで失われる。

## 影響

- すべての画面で、`stimulus.min.js` と `stimulus-loading.js` の取得が無くなる。
  importmap が配る項目は `application` と `@hotwired/turbo-rails` の 2 つになる
- Turbo の振る舞いは変わらない。
  `turbo_confirm` を使う 2 か所（応募の取り下げ、プロフィールの削除）は、
  Turbo Drive が処理しており Stimulus を経由していない
- `window.Stimulus` は存在しなくなる。参照するコードは無い
- CSP は変更しない。`script-src` は `self` のままである
- 画面の見た目に変更はない

## 扱わないこと

**`importmap-rails` は外さない。**

`@hotwired/turbo-rails` と `application` の pin が残る。
importmap は Turbo を配るために必要である。

**`vendor/javascript/` は残す。**

`bin/importmap pin` が取得したものを置く場所であり、
importmap を使い続ける以上、置き場所も残る。

**[ADR 0045](0045-content-security-policy.md) の本文は書き換えない。**

「Importmap と Stimulus で足りている」という記述は、
CSP を決めた時点の判断の記録である。
ADR は判断時点の記録として残し、後からの変更で書き換えない。
nonce を使わない結論は、Stimulus の有無によって変わらない。
