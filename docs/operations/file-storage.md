# ファイルの保存先

この文書は日本語版を正本とする。

RoleWeave は求職者が添付した履歴書・職務経歴書を Active Storage で保存する。
方針は [`docs/decisions/0031-profile-documents.md`](../decisions/0031-profile-documents.md) を正本とする。

## 保存先

`config/storage.yml` で定義している。

| 環境 | サービス | 保存先 |
| --- | --- | --- |
| development | `Disk` | `storage/` |
| test | `Disk` | `tmp/storage/` |
| production | `Disk` | `storage/` |

外部のオブジェクトストレージ（S3、GCS など）は設定していない。
利用するには依存の追加が必要であり、必要になった時点で判断する。

## 自己ホストで運用する場合に必要なこと

**`storage/` を永続化すること。**

`storage/` を残さないと、添付したファイルだけが失われる。
データベースには添付の記録（`active_storage_attachments`、`active_storage_blobs`）が残るため、
画面には添付があるように見えて、開こうとすると失敗する状態になる。

Docker で動かす場合、`compose.yaml` は作業ツリー全体を bind mount している。
`storage/` はホスト側のリポジトリの中に残る。
本番向けに別の構成へ置き換える場合は、`storage/` を named volume か
ホストのディレクトリへ明示的に割り当てる。

**バックアップの対象へ含めること。**

データベースのバックアップだけでは、添付は復元できない。
`storage/` とデータベースは同じ時点のものを組で保管する。
片方だけ新しいと、記録はあるがファイルがない添付、
あるいは参照されないファイルが残る。

**保存先の容量を監視すること。**

1 つの添付の上限は 10 MB である（`CandidateProfile::DOCUMENT_MAX_BYTE_SIZE`）。
1 人あたり最大 2 つ（履歴書・職務経歴書）を持つ。
利用者数から必要な容量の上限を見積もれる。

## 配信

添付は Active Storage の署名付き URL では配らない。
アプリケーションの経路（`ProfileDocumentsController`、
`Organizations::CandidateProfileDocumentsController`）から、
毎回ログイン状態と公開範囲を確かめて返す。

外部へファイルを配る CDN やリバースプロキシを前段へ置く場合、
これらの経路の応答をキャッシュしてはならない。
同じ URL への応答が、閲覧者によって「返す」と「404」に分かれるためである。
