# バックアップと復元

この文書は日本語版を正本とする。

RoleWeave の状態は 2 か所にある。**両方を同じ時点の組で扱う。**

| 対象 | 中身 | 場所 |
| --- | --- | --- |
| データベース | アカウント、プロフィール、求人、応募、記録 | PostgreSQL（`postgres_data` volume） |
| ファイル | 履歴書・職務経歴書の実体 | `storage/`（[`file-storage.md`](file-storage.md)） |

片方だけを戻すと、次の状態になる。

- データベースだけ新しい: 記録はあるがファイルがない添付が現れる
- ファイルだけ新しい: どこからも参照されないファイルが残る

## 名前の正本

コマンドへ書く利用者とデータベースの名前は、環境ごとに違う。
**この文書に数えるのではなく、次の 2 つを見る。**

| 環境 | 利用者 | データベース | 正本 |
| --- | --- | --- | --- |
| 開発（`docker compose`） | `roleweave` | `role_weave_development` | [`compose.yaml`](../../compose.yaml) |
| production | `role_weave` | `role_weave_production` ほか | [`config/database.yml`](../../config/database.yml) |

以下の例は開発の compose 環境で動く形にしてある。
production では、上の表に従って `-U` と対象のデータベースを置き換える。

## production のデータベース

production は 3 つのデータベースを使う（[`config/database.yml`](../../config/database.yml)）。
**取る対象が違う。**

| 名前 | 中身 | 失うと何が起きるか |
| --- | --- | --- |
| `role_weave_production` | 業務のデータすべて | 取り返せない。**必ず取る** |
| `role_weave_production_queue` | Solid Queue の未実行のジョブ | 送っていない通知・スカウト・Webhook の配信が消える。**取る** |
| `role_weave_production_cache` | Solid Cache | 作り直せる。取らなくてよい |

`cache` を取らない判断は、中身がキャッシュだからである。
ただし `rate_limit` の計数もここにある（[ADR 0044](../decisions/0044-rate-limiting.md)）。
復元の直後は、上限の計数が空の状態から始まる。

Action Cable は読み込んでいないため、cable データベースは存在しない
（[ADR 0065](../decisions/0065-no-unused-rails-frameworks.md)）。

## バックアップ

### データベース

```bash
docker compose exec db pg_dump -U roleweave -Fc role_weave_development > roleweave-$(date +%Y%m%d).dump
```

`-Fc`（カスタム形式）を使うと、復元時に並列化と部分復元ができる。

production では、業務のデータと未実行のジョブの 2 つを取る。

```bash
pg_dump -U role_weave -Fc role_weave_production > roleweave-$(date +%Y%m%d).dump
pg_dump -U role_weave -Fc role_weave_production_queue > roleweave-queue-$(date +%Y%m%d).dump
```

### ファイル

```bash
tar -czf storage-$(date +%Y%m%d).tar.gz storage/
```

### 同じ時点でそろえる

書き込みを止められる場合は、止めてから両方を取る。
止められない場合は、**ファイル → データベースの順**に取る。

先にファイルを取ると、その後に追加されたファイルの記録だけがデータベースへ入る。
逆の順にすると、記録のない添付が現れる。
「記録はあるがファイルがない」ほうが、原因を追いやすい。

## 復元

1. アプリケーションを止める

```bash
docker compose down
```

2. データベースを戻す

```bash
docker compose up -d db
docker compose exec -T db pg_restore -U roleweave -d role_weave_development --clean --if-exists < roleweave-YYYYMMDD.dump
```

production では、業務のデータと未実行のジョブの両方を戻す。

```bash
pg_restore -U role_weave -d role_weave_production --clean --if-exists < roleweave-YYYYMMDD.dump
pg_restore -U role_weave -d role_weave_production_queue --clean --if-exists < roleweave-queue-YYYYMMDD.dump
```

3. ファイルを戻す

```bash
rm -rf storage/
tar -xzf storage-YYYYMMDD.tar.gz
```

4. 起動して確かめる

```bash
docker compose up -d
docker compose run --rm app bin/rails runner 'puts ActiveStorage::Blob.count'
```

添付の件数と `storage/` の中身が食い違う場合は、組がそろっていない。

## 復元で起こること

**削除したはずのデータが戻る。**

- 退会したアカウント（ADR 0033）
- 保持期限で消したデータ（ADR 0046）
- 取り消した応募（ADR 0035 では状態を変えるだけなので、内容は元から残る）

復元は「その時点の状態へ戻す」操作である。
削除の要求を受けて消したデータがある場合、復元の後に**もう一度消す**必要がある。
いつ何を消したかは、この仕組みの外で控えておく。

## 確かめておくこと

バックアップは、復元できて初めてバックアップである。

- 取得したファイルが空でないこと
- 別の環境へ復元して起動できること
- 添付が開けること

定期的に確かめる。取れているつもりの状態が、いちばん危ない。
