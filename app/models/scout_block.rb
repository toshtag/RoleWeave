# 候補者による組織ごとの配信停止。
#
# 「探されてよい」と「この会社からは受け取りたくない」は別である。
# 方針は docs/decisions/0056-scouting.md を正本とする。
class ScoutBlock < ApplicationRecord
  belongs_to :candidate_profile
  belongs_to :organization

  attr_readonly :candidate_profile_id, :organization_id

  validates :organization_id, uniqueness: { scope: :candidate_profile_id }
end
