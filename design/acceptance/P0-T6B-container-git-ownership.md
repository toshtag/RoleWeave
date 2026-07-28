# P0-T6B 受け入れ条件 — コンテナ内の作業ツリー所有者

この文書は P0-T6B の受け入れ条件の正本とする。
P0-T6B の実装者は、着手前にこの文書を読み、完了報告でここの各項目に対する結果を示す。

## 目的

bind mount した作業ツリーの所有者がコンテナの実行ユーザーと異なるホストでも、
`docker compose run --rm app bin/verify` が成立する状態にする。

## 変更前の問題

`compose.yaml` は作業ツリーを `/workspace` へ bind mount し、コンテナは root で動作する。

Linux ホストでは、bind mount されたファイルの所有者がホスト側の実行ユーザーのままになる。
コンテナの root と一致しないため、Git 2.35.2 以降は作業ツリーを拒否する。

```text
fatal: detected dubious ownership in repository at '/workspace'
```

Code Pact は `reads` の glob を Git の追跡ファイル索引に対して解決する。
索引を読めないと、追跡ファイルの有無を判定できず、厳格 lint が全タスク分のエラーを返す。

```text
TASK_READS_UNAVAILABLE
Task reads globs require a readable Git tracked-file index;
untracked filesystem walks are not allowed.
```

その結果、コンテナ内の標準検証が Code Pact 厳格 lint で失敗する。

macOS の Docker Desktop は bind mount の所有者をコンテナの実行ユーザーへ写像するため、
この欠陥は macOS 上では再現しない。

これは P0-T4 で構築した Docker 開発基盤と、P0-T6 で確立した検証入口の欠陥であり、
GitHub Actions 固有の問題ではない。Linux をホストとする開発者環境でも同じ結果になる。

P0-T7 の GitHub Actions は ubuntu runner で `bin/ci` を実行するため、
本タスクの修正がない限り成立しない。P0-T7 は P0-T6B へ依存する。

## 修正方針

`bin/docker-entrypoint` で、`/workspace` を Git の安全なディレクトリとして登録する。

- 例外の対象は `/workspace` だけとする
- `safe.directory` へ `*` を設定しない。任意のディレクトリを一括で許可しない
- 所有者そのものを書き換えない。bind mount 先の所有者はホストの責務とする
- コンテナの実行ユーザーを変更しない。P0 の範囲では root のまま扱う
- `Dockerfile` へ焼き込まず、起動時の前処理として扱う。
  実行環境に依存する設定であり、イメージの内容ではない

## 実装要件

設定命令は次と完全に一致する 1 行だけとする。

```bash
git config --global --replace-all safe.directory /workspace
```

- `bin/docker-entrypoint` のコメントを除いた本文で、`safe.directory` を含む行はこの 1 行だけとする
- `--add` を使用しない。何度実行しても設定が重複して蓄積しないこと
- 設定命令は `exec "$@"` より前に置く
- 新規の gem、npm 依存、apt パッケージを追加しない
- `bin/verify`、`bin/ci`、`bin/setup` の責務を変更しない
- `compose.yaml` と `Dockerfile` を変更しない

## 検証要件

`scripts/verify-p0-docker` へ、P0-T6B の進捗イベントが記録された時点で有効になる検証を追加する。

### 静的検証

- `bin/docker-entrypoint` が bash として構文的に正しいこと
- 上記の設定命令が、行全体の完全一致でちょうど 1 回だけ現れること
- コメントを除いた本文で `safe.directory` を含む行が 1 行だけであること
- 設定命令が `exec "$@"` より前の行にあること

行全体の完全一致で判定する。部分一致の正規表現では、
`--replace-all` を `--add` へ退行させた実装を検出できない。

### 動的検証

- コンテナ内の global 設定で、`safe.directory` の一覧が `/workspace` の 1 件だけであること。
  包含関係ではなく完全一致で判定する
- 同じコンテナ内で `bin/docker-entrypoint` を追加で実行しても、一覧が `/workspace` の 1 件だけであること。
  `docker compose run` は毎回新しいコンテナを起動するため、
  起動 1 回だけの観測では `--add` による重複を検出できない
- コンテナ内から作業ツリーの Git 索引を読めること
- 所有者の異なる `/workspace` 以外のリポジトリが、依然として Git に拒否されること

所有者が写像されるホストでは、修正前でも作業ツリーの Git 索引を読める。
そのため、例外の適用範囲と冪等性を確認する検証を必ず併せて行う。

## 正の検証

- `docker compose run --rm app bin/verify` が exit 0 で終了する
- `bin/verify --full` が exit 0 で終了する
- P0-T3 から P0-T6A までの既存検証がすべて成功する
- Linux ホスト（GitHub Actions ubuntu runner）で `bin/ci` が exit 0 で終了する

## 負の検証

次を `bin/docker-entrypoint` へ一時的に加えた場合、`bin/verify --full` が非 0 で終了すること。

```text
設定命令を削除する
/workspace を * へ変更する
--replace-all を --add へ変更する
別の safe.directory 設定を追加する
設定命令を exec "$@" より後ろへ移動する
```

静的検査を迂回した実装（引用符などで文字列一致を外した一括許可）も、
動的検証で拒否されること。

一時変更はすべて復元し、一時的な Docker resource を残さない。

## 既存検証の維持

P0-T6B を理由に、P0-T3 / P0-T4 / P0-T4A / P0-T5 / P0-T6 / P0-T6A で確立した検証を削除・弱体化しない。

## 非目標

次は P0-T6B で実装しない。

```text
コンテナ実行ユーザーの変更（root からの移行）
bind mount 先の所有者の書き換え
Dockerfile の変更
compose.yaml の変更
bin/verify / bin/ci / bin/setup の責務変更
GitHub Actions の Workflow 定義（P0-T7）
セキュリティと依存関係検査（P0-T9）
```

## 変更禁止範囲

次のファイルを P0-T6B で変更しない。

```text
app/**
config/**
db/**
test/**
Gemfile / Gemfile.lock
package.json / package-lock.json
Dockerfile
compose.yaml
bin/verify
bin/ci
bin/setup
scripts/verify-p0
.github/**
README.md / README.en.md
docs/**
P1 以降の phase 契約
```

`design/` は、`task start` 前の契約コミットと `task finalize --write` による正規更新を除いて変更しない。

## 実装時の注意

- `design/phases/*.yaml` は Code Pact の保護パスであるため、P0-T6B の `writes` へ宣言しない
- finalize は dry-run と `--write` の両方で `--audit-strict` を指定する。
  `--base-ref` には P0-T6B の契約コミットを指定する
- `write_audit` の不整合をダミー差分で解消しない。原因を報告して停止する
