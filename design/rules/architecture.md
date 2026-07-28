---
tags: [architecture, rails, data]
applies_to: [architecture, feature, bugfix, refactor, mechanical_refactor]
---

# アーキテクチャルール

詳細な正本は [`docs/architecture/principles.md`](../../docs/architecture/principles.md) とする。
このファイルは、タスク実行時に必ず守る要点だけを示す。

- 単一の Rails アプリケーションによるモジュラーモノリスとし、業務境界は Ruby の名前空間で表現する。
  初期段階でサービス分割を行わない。
- PostgreSQL を業務上の正本とする。検索インデックスや UI 上の状態を正本にしない。
- Rails 標準の構造と命名・autoload 規約を維持する。独自の autoload root を追加しない。
- 外部サービス（メール、ファイル保存、CRM、カレンダー、Webhook）は、
  アプリケーション側が定義したインターフェースの背後に置く。業務モジュールから外部 SDK を直接参照しない。
- 外部 API をデータベーストランザクション内で呼ばない。
- Active Record callback から外部副作用（通信・メール送信）を起こさない。
- 業務ルールを Controller に置かない。
- 将来用の空ディレクトリを作らない。同じ責務を表す別ルートを並立させない。
- 初期段階で React、Next.js、GraphQL、Redis、OpenSearch、Kafka、Kubernetes を採用しない。
