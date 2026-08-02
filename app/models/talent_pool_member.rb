# タレントプールへ入れた候補者。
#
# 方針は docs/decisions/0055-candidate-search.md を正本とする。
class TalentPoolMember < ApplicationRecord
  belongs_to :talent_pool
  belongs_to :candidate_profile
  belongs_to :added_by, class_name: "User", optional: true

  attr_readonly :talent_pool_id, :candidate_profile_id, :added_by_id

  # 同じ候補者を同じプールへ 2 回入れても意味がない。
  validates :candidate_profile_id, uniqueness: { scope: :talent_pool_id }

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  # いま探せる候補者だけを返す。
  #
  # 入れた時点の許可ではなく、**いまの許可**で決める。
  # 取り消した後も、入れた組織だけが見続けられるのであれば、
  # その同意は撤回できないことになる（ADR 0055）。
  #
  # 判定そのものは持たない。`CandidateProfile.searchable` を正本として引く。
  # ここへ条件を書き写すと、片方だけを直した状態が生まれる。
  scope :searchable, -> { where(candidate_profile_id: CandidateProfile.searchable.select(:id)) }
end
