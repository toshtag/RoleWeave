# ADR 0069: Pull Request の検証から Docker 基盤を外す

- 状態: 採用
- 決定日: 2026-08-03

この文書は日本語版を正本とする。

## 背景

CI は `bin/ci` から `bin/verify --full` を呼び、P0 完全検証をそのまま実行していた。

```
bin/ci -> bin/verify --full -> scripts/verify-p0 -> scripts/verify-p0-docker
```

1 回の実行は 2 分 45 秒だった。内訳を計測すると、次のようになる。

| 区間 | 時間 | 何を検証しているか |
| --- | --- | --- |
| Docker イメージの build | 54 秒 | apt と `bundle install` を毎回やり直す |
| compose up と冪等性検証 | 38 秒 | `bin/setup` を 2 回実行して差が無いことを見る |
| P0 基盤の静的契約検査 | 34 秒 | 文書・`.gitignore`・i18n 設定。Rails を 6 回 boot する |
| アプリケーションの検証 | 34 秒 | RuboCop・Brakeman・bundler-audit・Zeitwerk・テスト |
| checkout と Ruby の準備 | 5 秒 | |

**アプリケーションを守っているのは 34 秒だけである。**

残る 131 秒は開発環境の契約を検証している。
`app/` の 1 行を変えた Pull Request でも、Docker イメージを build し直し、
Compose を起動し、`bin/setup` を 2 回実行する。

この費用は寄稿者が払う。
自分の変更と関係のない理由で、3 分近く待ってから結果を見ることになる。

Workflow の構造検査（`scripts/verify-github-actions`、502 行）も同じ形だった。
job を 1 つに固定し、job 名・step 名・step の並び・キーの集合・
`30` に対する `30.0` や `0x1e` といったスカラーの書き方まで完全一致で見ていた。
表記を固定しても守れるものが無く、CI の構成を変える費用だけが残っていた。

## 決定

- Pull Request の検証は、アプリケーションの検証だけにする
- PostgreSQL はイメージを build せず、GitHub Actions の service コンテナで用意する。
  版の正本は `compose.yaml` とし、Workflow はその値を写す
- job を **テスト** と **静的解析** の 2 つへ分け、並行に実行する
- `bin/ci` を落とす。`bin/verify --full` へ委譲するだけの別名だった
- 検証内容の正本は `bin/verify` のままとする。
  Workflow が実行するコマンドは、すべて `bin/verify` にも並ぶことを構造検査で固定する
- Workflow の構造検査は、壊れても気づけないものだけに絞る。
  Action の SHA 固定、service イメージの版、権限、secrets の不参照、
  runner の版、timeout、`bin/verify` に無いコマンドの拒否
- **`bin/verify --full` は残す。**Docker 基盤と冪等性の検証は、
  引き続きローカルで実行し、Pull Request へ結果を書く

## 理由

**CI が守る対象と、待たせる相手が合っていなかった。**

Docker 基盤の検証が守るのは、開発環境を作り直したときの再現性である。
それが壊れるのは `Dockerfile` と `compose.yaml` を変えたときであり、
`app/` を変えたときではない。

にもかかわらず、費用はすべての Pull Request が等しく払っていた。

**寄稿者にとって、待ち時間は参加の費用そのものである。**

このリポジトリは個人が開発している OSS で、寄稿者を歓迎すると書いている
（[`CONTRIBUTING.md`](../../CONTRIBUTING.md)）。

3 分待たされる CI は、小さな修正を送る動機を確実に削る。
とくに、書き間違いを直して push し直すたびに 3 分を払う形は、
「試しに直してみる」という行動を止める。

**job を分けるのは、失敗を早く返すためである。**

RuboCop の指摘は約 15 秒で返せる。
テストの完了を待ってから返す理由が無い。
どちらが落ちたかも job 名で読めるようになる。

**正本を 1 つに保つ仕組みは、形を変えて残す。**

これまでは「Workflow は `bin/ci` だけを呼ぶ」という形で正本を守っていた。
job を分けると、この形は使えない。

代わりに、Workflow の `run` に書かれたコマンドが
すべて `bin/verify` にも並んでいることを構造検査で確かめる。
CI にしか無い検査も、CI だけが握り潰す失敗も作れない。

**構造検査は、表記ではなく壊れ方を見るものにする。**

job 名を別の固定値へ変えても、step を並べ替えても、CI が守るものは変わらない。
一方、Action の SHA が可変タグへ戻れば、同じ参照が別の実装へ差し替わる。
service の PostgreSQL がローカルと違う版になれば、片方だけ通る差分を作れる。

前者を固定する費用は、CI の構成を変えるたびに発生する。
後者を固定しなければ、壊れても気づけない。検査する対象を後者へ寄せる。

## 影響

- Pull Request の検証は約 2 分 45 秒から約 35 秒へ短くなる。
  テスト job が律速で、静的解析 job は約 15 秒で返る
- `Dockerfile` と `compose.yaml` の退行は CI では検出されない。
  検出は `bin/verify --full` の責務であり、
  [`CONTRIBUTING.md`](../../CONTRIBUTING.md) が要求する実行結果で担保する
- P0 基盤の静的契約検査（文書の正本、`.gitignore`、i18n の実動作）も
  CI では実行されない。同じく `bin/verify --full` の責務とする
- `bin/ci` は存在しなくなる。`bin/verify` を直接実行する
- `config/ci.rb` を持たない状態は変わらない
- テストの内容・件数・並列度は変更しない

## 扱わないこと

**`bin/verify --full` の中身は削らない。**

Docker 基盤の検証も、P0 の静的契約検査も、実行する場所を変えただけである。
どこまでを契約として持ち続けるかは、このタスクの範囲外とする。

**Workflow を増やさない。**

`Dockerfile` の変更時だけ Docker 検証を走らせる path filter 付きの
Workflow を足す案は採らない。
必須チェックが条件付きで skip される形は、
「通っているのか、走っていないのか」が読めなくなる。

**bundler-audit を CI から外さない。**

advisory database の更新は外部通信を伴い、
Gemfile.lock を変えていない Pull Request でも、
新しい脆弱性が公表された日に落ち得る。

これは誤検出ではない。落ちるべきときに落ちている。
静的解析 job は約 1 秒しか払っておらず、テストの完了より先に返る。

**[ADR 0064](0064-no-image-variant-processing.md) の本文は書き換えない。**

`bin/ci` に触れている記述は、判断時点の記録である。
ADR は後からの変更で書き換えない（[ADR 0068](0068-no-stimulus.md)）。
