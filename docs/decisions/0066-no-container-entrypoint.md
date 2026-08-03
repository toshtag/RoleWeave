# ADR 0066: コンテナに entrypoint の層を置かない

- 状態: 採用
- 決定日: 2026-08-03

この文書は日本語版を正本とする。

## 背景

`Dockerfile` は `ENTRYPOINT ["bin/docker-entrypoint"]` を宣言し、
`bin/docker-entrypoint` がコンテナ起動時の前処理を担っていた。

前処理として書かれていたのは 1 行である。

```bash
# 前回の異常終了で残った Puma の PID ファイルだけを取り除く。
rm -f /workspace/tmp/pids/server.pid
```

この 1 行は、[#228](https://github.com/toshtag/RoleWeave/issues/228) で外した。
残骸かどうかを判定しておらず、`docker compose run` の一時コンテナが
動作中のサーバーの PID ファイルまで消していたためである。

実測（Rails 8.1.3.1 / Puma 8.0.2）では、削除する側の理由も無かった。

| 状況 | 結果 |
| --- | --- |
| 残骸（存在しない PID）を置いて `bin/rails server` | 起動する。PID ファイルは実際の PID で上書きされる |
| 動作中の PID がある状態で 2 つ目を起動 | `A server is already running (pid: ...)` で止まる |

残骸は起動を妨げず、動作中の PID は二重起動を止める。
削除は前者を守っておらず、後者の判定だけを壊していた。

外した結果、`bin/docker-entrypoint` に残ったのは次だけになった。

```bash
#!/usr/bin/env bash
set -euo pipefail

exec "$@"
```

与えられたコマンドを、そのまま実行する。それだけを行う。

## 決定

- `Dockerfile` から `ENTRYPOINT` を外す
- `bin/docker-entrypoint` を削除する
- `Dockerfile` が `ENTRYPOINT` を宣言していないことと、
  `bin/docker-entrypoint` が存在しないことを、完全検証で固定する
- `CMD`、`EXPOSE`、`compose.yaml` の `init: true` は変更しない
- コンテナ起動時の前処理が必要になったときは、
  何のための前処理かを決めたうえで、そのときに層を足す

## 理由

**呼ばれないものを落とす基準を、ここにも当てる。**

このリポジトリは同じ判断を繰り返している。

| | 落としたもの |
| --- | --- |
| [ADR 0064](0064-no-image-variant-processing.md) | 画像処理の依存と libvips |
| [ADR 0065](0065-no-unused-rails-frameworks.md) | 使わない Rails のフレームワークと cable データベース |
| [#217](https://github.com/toshtag/RoleWeave/issues/216) | 一度も呼ばれていない gem |
| [#225](https://github.com/toshtag/RoleWeave/pull/225) | 一度も呼ばれていない PostgreSQL クライアント |

理由はいずれも同じで、入れておくと、更新も追跡も、
何のために続けているのか分からないまま残る。
`exec "$@"` だけの entrypoint は、同じ基準に当てはまる。

**「あとで何か入れるかもしれない」は、いま持つ理由にならない。**

前処理を足すのは `ENTRYPOINT` 1 行とファイル 1 つである。
そのときは「何のための前処理か」が決まっているため、
どのコンテナで走るべきかも一緒に決められる。

いま空の層だけを持っていると、次に何かを足す人は
「ここに書けばよい」と判断する。#228 で起きたのはそれである。
サーバーのための前処理を、すべてのコンテナで走る場所へ書いてしまった。

**速くなるからではない。**

entrypoint は `exec` で自分を置き換えていたため、プロセスは常駐していない。

```
変更前  1 /sbin/docker-init -- bin/docker-entrypoint bin/rails server -b 0.0.0.0
        6 puma 8.0.2 (tcp://0.0.0.0:3000) [workspace]

変更後  1 /sbin/docker-init -- bin/rails server -b 0.0.0.0
        6 puma 8.0.2 (tcp://0.0.0.0:3000) [workspace]
```

減るのは起動時の fork と exec が 1 回ずつで、時間として測れる差ではない。
減らしているのは、読む側が追う対象の数である。

## 影響

- コンテナへ渡したコマンドは、間に何も挟まず実行される。
  `docker compose up`、`docker compose run --rm app <コマンド>` の
  いずれも結果は変わらない
- `--entrypoint=""` による迂回が不要になる。
  リポジトリ内にこの指定を使っている箇所は無い
- PID 1 と signal の扱いは変わらない。
  `compose.yaml` の `init: true` がそのまま `docker-init` を置く
- 完全検証の該当箇所は、`bin/docker-entrypoint` の内容の検査から、
  層が存在しないことの検査へ変わる

## 扱わないこと

**`CMD` は変更しない。**

`CMD ["bin/rails", "server", "-b", "0.0.0.0"]` は、
`compose.yaml` の `command` と同じ内容を持つ。
Compose を使わない `docker run` でサーバーが起動する形を残す。

**`init: true` は変更しない。**

signal の転送と孤児プロセスの回収は `docker-init` の役割であり、
entrypoint の層とは別である。

**本番用イメージは扱わない。**

P0 では本番用イメージを扱わない方針のままとする。
本番用イメージを作るときに前処理が必要になったら、
そのイメージの Issue で、何を行うかと合わせて決める。
