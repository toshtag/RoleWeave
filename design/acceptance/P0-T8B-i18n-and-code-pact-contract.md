# P0-T8B 受け入れ条件 — i18n 単一正本の回帰検査と Code Pact 手順の整合

この文書は P0-T8B の受け入れ条件の正本とする。
P0-T8B の実装者は、着手前にこの文書を読み、完了報告でここの各項目に対する結果を示す。

## 目的

P0-T8A のレビューで判明した次の 2 件を、実装・検証・開発文書で一致させる。

1. i18n フォールバックの単一正本を、累積検証が保証していない
2. Code Pact の標準ライフサイクル文書が、実際に成立する順序と矛盾している

現在のファイルの内容そのものは正しい。修正対象は検証器と開発文書である。

## 変更前の問題

### 単一正本を検証器が保証していない

P0-T8A の受け入れ条件は、フォールバックの正本を
`config/application.rb` の 1 件だけと定めている。

しかし `scripts/verify-p0` の静的検査が拒否するのは、
`config/environments/production.rb` にある次の記述だけである。

```ruby
config.i18n.fallbacks = true
```

そのため、次はいずれも検証を通過する。

```ruby
# config/environments/production.rb
config.i18n.fallbacks = false
```

```ruby
# config/environments/development.rb
config.i18n.fallbacks = true
```

重複した `false` は現在の挙動を変えないため、production boot の振る舞い検査でも検出できない。
development への `true` は、production probe と test 環境のテストのどちらの対象でもない。

つまり「正本は 1 か所だけ」と「すべての実行環境で成立させる」の 2 つが、
どちらも回帰検査で固定されていない。

### Code Pact の標準手順が実装と矛盾している

`code-pact verify --phase <ID> --task <ID>` は 4 つの check を行う。

```text
commands        フェーズ検証コマンドの実行
progress_event  done イベントの存在（task complete が記録する）
decision        判断記録
task_status     フェーズ YAML の status が done（task finalize --write が更新する）
```

`task_status` は `task finalize --write` の後でなければ成立しない。

一方、次の 2 文書は `verify` を `task complete` より前に置いている。

```text
docs/development/code-pact.md
design/rules/code-pact-execution.md
```

この順序では `verify` が必ず `invalid_state` で失敗する。
`verify` は毎回フェーズ検証コマンド（`bin/verify --full`）を実行するため、
順序を誤ると Docker build を含む数分の実行が丸ごと無駄になる。

正本を読んだ実装者が同じ失敗を繰り返すため、P0-T10 へ繰り越さない。

## 実装要件

### i18n フォールバックの単一正本

検査対象は次の 4 ファイルだけとする。

```text
config/application.rb
config/environments/development.rb
config/environments/test.rb
config/environments/production.rb
```

`config.i18n.fallbacks` への有効な代入は、次のちょうど 1 件だけを許可する。

```text
config/application.rb の config.i18n.fallbacks = false
```

次を拒否する。

```text
config/environments/*.rb での再定義（値が true か false かを問わない）
config/application.rb での true への変更
config/application.rb からの正本の削除
同じファイル内での重複した代入
```

`config/environments/*.rb` では、値にかかわらず再定義を禁止する。
同じ設定を 2 箇所へ書くと、次に片方だけ変更されたときに矛盾が生まれる。
現在の挙動を変えない重複であっても、正本が 2 つになった時点で契約違反として扱う。

### 検出方法

単純な文字列の件数や、コメント行を除いただけの grep で判定しない。
Ruby の構文解析を通し、コード上の有効な代入式だけを数える。

次は代入として数えない。

```text
コメント内の記述
文字列リテラル内の記述
```

空白や改行の違いで検査を回避できないようにする。

検出結果は、少なくとも次を保持する。

```text
ファイルパス
行番号
代入値
```

期待値と一致しない場合は、実際に検出した代入の一覧を表示して失敗する。
「何件あるか」だけでは、どこを直せばよいか分からない。

### 実装場所

新しい永続スクリプトファイルを追加しない。
`scripts/verify-p0` の P0-T8B 検査として、その中の Ruby ブロックで実装する。

P0-T8A の production boot probe は削除しない。
単一正本検査は「設定が 1 か所にあること」を、
boot probe は「実際にフォールバックしないこと」を保証する。役割が異なる。

### Code Pact 運用文書

次の 2 文書の順序を、実際に成立する順序へ統一する。

```text
docs/development/code-pact.md
design/rules/code-pact-execution.md
```

正規順序。

```text
task prepare
task start
実装
task complete
task finalize --audit-strict --json         （dry-run）
task finalize --audit-strict --write --json
code-pact verify --phase <ID> --task <ID>
```

次を説明として記載する。

- `task complete` がフェーズ検証コマンドを実行し、done イベントを記録する
- `task finalize --write` がフェーズ YAML のタスク status を `done` へ更新する
- タスク指定の `verify` は done イベントとフェーズ YAML の status の両方を確認する
- したがってタスク指定の `verify` は finalize の後に行う
- 最終 `verify` が失敗した場合、その結果を成功として扱わない

`verify → task complete → task finalize` を正規手順として残さない。

dry-run、`--write`、`--audit-strict`、`write_audit` の確認に関する既存の規則は維持する。

### 生成物

`docs/code-pact/agent-instructions.md` は Code Pact が管理する生成物である。
手作業で編集しない。編集すると `adapter doctor` が `ADAPTER_FILE_DRIFT` を報告する。

## 履歴の扱い

P0-T8 と P0-T8A の進捗イベント（`.code-pact/state/events/**`）を変更・削除しない。

`design/acceptance/P0-T8A-production-i18n-fallback.md` の実行時注意は、
P0-T8A 実施時の記述として残したうえで、実測で判明した正しい順序を追記する。
P0-T8A を当初から正しい手順で実行したように書き換えない。

## 正の検証

- `bash -n scripts/verify-p0` が成功する
- 単一正本検査が、現在のリポジトリに対して exit 0 で終了する
- 検出された代入がちょうど 1 件で、`config/application.rb` の `false` である
- P0-T8A の production boot probe が引き続き成功する
- 2 つの正本文書に `complete → finalize → verify` の順序が記載されている
- 2 つの正本文書に旧順序の記述が残っていない
- `docker compose run --rm app bin/verify` が exit 0 で終了する
- `bin/verify --full` が exit 0 で終了する
- `npm run pact:validate` と `npm run pact:lint` が exit 0 で終了する
- 最終 HEAD に対応する GitHub Actions の run が success で終了する

## 負の検証

一時 bind mount で変異ファイルを差し込み、恒久ファイルを書き換えずに実施する。
次がいずれも非 0 で拒否されること。

```text
production へ重複した config.i18n.fallbacks = false を追加する
development へ config.i18n.fallbacks = true を追加する
test へ config.i18n.fallbacks = false を追加する
config/application.rb から正本を削除する
config/application.rb を true へ変更する
```

次を誤検出しないこと。

```text
コメント内の # config.i18n.fallbacks = true
文字列リテラル内の "config.i18n.fallbacks = true"
```

各ケースの後、恒久ファイルが元の状態であることを確認する。

## 既存検証の維持

P0-T8B を理由に、P0-T1 から P0-T8A までで確立した検証を削除・弱体化・並べ替えしない。

- P0-T8A の production boot probe
- P0-T8 の i18n 構成テスト（12 件）と累積検証
- `bin/ci` が `bin/verify --full` へだけ委譲する構造

## 非目標

次は P0-T8B で実装しない。

```text
i18n の設定値そのものの変更
production での翻訳欠落の扱い（例外化・監視・利用者への表示）
言語切替 UI、locale 付き URL、画面の追加
新しい依存関係の追加
新しい永続検証スクリプトの追加
docs/code-pact/agent-instructions.md の手編集
セキュリティと依存関係検査（P0-T9）
Foundation 完了検証（P0-T10）
```

## 変更禁止範囲

次のファイルを P0-T8B で変更しない。

```text
config/application.rb
config/environments/development.rb
config/environments/test.rb
config/environments/production.rb
config/locales/**
config/routes.rb
app/**
test/**
Gemfile / Gemfile.lock
package.json / package-lock.json
compose.yaml
Dockerfile
.github/**
bin/**
scripts/verify-p0-docker
docs/code-pact/agent-instructions.md
README.md / README.en.md
P1 以降の phase 契約
```

`design/` は、`task start` 前の契約コミットと `task finalize --write` による正規更新を除いて変更しない。

## 実装時の注意

- `design/phases/*.yaml` は Code Pact の保護パスであるため、P0-T8B の `writes` へ宣言しない
- 完了処理はこの文書が定める正規順序で行う。
  `task complete` → `task finalize --write` → `verify`
- finalize は dry-run と `--write` の両方で `--audit-strict` を指定し、
  `--base-ref` には P0-T8B の契約コミットを指定する
- `write_audit` の不整合をダミー差分で解消しない。原因を報告して停止する
- 実行していない検証を成功として報告しない
