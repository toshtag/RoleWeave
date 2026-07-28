# P0-T6A 受け入れ条件 — bin/ci 委譲契約の厳格化

この文書は P0-T6A の受け入れ条件の正本とする。
P0-T6A の実装者は、着手前にこの文書を読み、完了報告でここの各項目に対する結果を示す。

## 目的

`bin/ci` が `bin/verify --full` へ委譲するだけの互換ラッパーであることを、
部分文字列の存在確認ではなく、実行行全体の構造検査で保証する。

## 変更前の問題

P0-T6 の検証は、次の行が `bin/ci` に含まれることだけを確認していた。

```bash
grep -Fq 'exec "$APP_ROOT/bin/verify" --full "$@"' bin/ci
```

そのため、独自の検証コマンドを前に置いても検証を通過する。

```bash
bin/rubocop
npm run pact:lint
exec "$APP_ROOT/bin/verify" --full "$@"
```

これは P0-T6 の次の契約に反する。

- `bin/ci` は委譲するだけの互換ラッパーとする
- 独自の検証コマンド一覧を持たない
- 検証内容の正本を `bin/verify` へ一本化する
- 「`bin/ci` へ独立した検証一覧を追加すると失敗する」という負の検証が成立していない

## 許可する実行構造

先頭の shebang は次と完全に一致する。

```text
#!/usr/bin/env bash
```

コメントと空行を除いた `bin/ci` は、次の構造と完全に一致する。

```text
set -euo pipefail
APP_ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.."
  pwd
)"
exec "$APP_ROOT/bin/verify" --full "$@"
```

許可するもの。

```text
日本語コメント
空行
現在の APP_ROOT 解決処理
最後の exec による bin/verify --full への委譲
```

禁止するもの。

```text
RuboCop の直接実行
Rails test の直接実行
Code Pact の直接実行
セットアップ
Docker
security audit
ファイル操作
環境設定の追加
exec の前後に置く任意のコマンド
複数の検証定義
```

## 実装要件

- 検査は Ruby で行い、行単位の完全一致で判定する
- shebang を検査する
- 無視するのはコメント行と空行だけとする
- `exec` より後ろの到達不能なコマンドも契約違反として扱う
- 日本語コメントの変更を不必要に拒否しない
- 外部 gem や新規の npm 依存を追加しない
- `eval` や shell parser を導入しない
- 構造検査は Docker 検証より前へ置き、契約違反を build より先に失敗させる

`bin/ci` の実体は P0-T6 の時点で正しいため、本タスクでは変更しない。

## 正の検証

- 現在の `bin/ci` が構造検査を通過する
- コメントと空行の追加が検証結果へ影響しない
- `bin/ci unexpected-argument` が `bin/verify` の引数検査によって非 0 になる
- `docker compose run --rm app bin/verify` が exit 0 で終了する
- `bin/verify --full` が exit 0 で終了する
- P0-T3 から P0-T6 までの既存検証がすべて成功する

## 負の検証

次を `bin/ci` へ一時的に加えた場合、`bin/verify --full` が Docker build より前に非 0 で終了すること。

```text
exec の直前へ bin/rubocop を追加する
exec の直前へ npm run pact:lint を追加する
exec の直前へ独自の printf 処理を追加する
exec より後ろへ到達不能なコマンドを追加する
```

一時変更はすべて復元し、一時的な Docker resource を残さない。

## 既存検証の維持

P0-T6A を理由に、P0-T3 / P0-T4 / P0-T5 / P0-T6 で確立した検証を削除・弱体化しない。
置き換えるのは `bin/ci` の委譲確認だけとし、それより厳格な検査へ差し替える。

## 非目標

次は P0-T6A で実装しない。

```text
bin/verify の検証内容の変更
bin/ci への新機能の追加
Rails test の追加
GitHub Actions（P0-T7）
セキュリティと依存関係検査（P0-T9）
検証時間の最適化
```

## 変更禁止範囲

次のファイルを P0-T6A で変更しない。

```text
bin/ci
bin/verify
bin/setup
scripts/verify-p0-docker
config/**
Dockerfile
compose.yaml
Gemfile / Gemfile.lock
package.json / package-lock.json
README.md / README.en.md
docs/**
.github/**
```

`design/` は、`task start` 前の契約コミットを除いて変更しない。

## 実装時の注意

- `design/phases/*.yaml` は Code Pact の保護パスであるため、P0-T6A の `writes` へ宣言しない。
  契約の登録は `task start` 前のコミットで済ませ、作業ツリーを clean にする
- タスクが削除するファイルを `reads` へ宣言しない。
  削除後に `plan lint` が `TASK_READS_NO_MATCH` を終了コードへ反映し、
  `bin/verify` の標準モードが恒久的に失敗する
- finalize は dry-run と `--write` の両方で `--audit-strict` を指定する
- `write_audit` の不整合をダミー差分で解消しない。原因を報告して停止する
