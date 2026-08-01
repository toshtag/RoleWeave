class AddDocumentsVisibleToCandidateProfiles < ActiveRecord::Migration[8.1]
  def change
    # 履歴書・職務経歴書は、このアプリケーションが持たないと決めた情報
    # （生年月日・性別・顔写真）を含みうる。公開範囲とは別に決める。
    # 詳細は docs/decisions/0031-profile-documents.md を参照する。
    add_column :candidate_profiles, :documents_visible, :boolean, null: false, default: false
  end
end
