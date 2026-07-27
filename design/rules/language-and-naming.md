---
tags: [language, naming, i18n]
---

# 開発言語・命名ルール

詳細な正本は [`docs/development/language-policy.md`](../../docs/development/language-policy.md) とする。
このファイルは、タスク実行時に必ず守る要点だけを示す。

- コードコメント、コミットメッセージの要約と本文、PR、Issue、レビュー記録、検証結果は日本語で書く。
- コード識別子、ファイル名、ディレクトリ名、データベース名、URL、API フィールド、
  構造化ログのキー、i18n キー、Git ブランチ名は自然な英語で書く。
- Conventional Commits の種別（`feat` / `fix` / `refactor` / `test` / `docs` / `chore` / `ci` / `perf`）は英語のままとする。
- 利用者向け表示はすべて i18n を経由し、日本語と英語を同等に扱う。
- 過去のシステムに由来する固有名詞を、コード・ドキュメント・デモデータへ持ち込まない。
- `RoleWeave` は Rails のアプリケーション設定名前空間に限定し、業務モデルや業務モジュールの
  共通親名前空間にしない。業務クラスへ `RoleWeave` を接頭辞として付けない。
- ブランチ名は `^[a-z0-9]+/[a-z0-9]+(?:-[a-z0-9]+)*$` に一致させる。
