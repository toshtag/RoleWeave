class CreateCandidateProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :candidate_profiles do |t|
      # プロフィールはアカウントへ 1 対 1 で従属する。
      # アカウントが消えたら残さない。
      # 詳細は docs/decisions/0026-candidate-profile.md を参照する。
      t.references :user, null: false, foreign_key: true, index: { unique: true }

      # 表示名だけを必須とする。ほかは後から埋められる。
      t.string :display_name, null: false

      t.text :introduction
      t.string :location
      t.string :desired_occupation

      # 生年月日・性別・顔写真は持たない。
      # 採用の判断に使ってはならない情報を、最初から保持しない。

      t.timestamps
    end
  end
end
