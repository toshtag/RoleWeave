# 組織が出す求人。
#
# 公開状態は 1 つのレコードが status として持つ。下書きと公開でレコードを分けない。
# 方針は docs/decisions/0016-job-posting-model.md を正本とする。
class JobPosting < ApplicationRecord
  TITLE_MAX_LENGTH = 200

  # 取り得る公開状態。値をここで閉じる。
  # 申請・審査・公開・停止は後続タスクで足す。使い道のない状態を先に並べない。
  STATUSES = %w[draft].freeze

  # 雇用形態。自由記述にすると、公開側の絞り込みで表記のゆれを吸収することになる。
  EMPLOYMENT_TYPES = %w[full_time part_time contract internship].freeze

  belongs_to :organization

  # 所属先の組織は、作成した後で変えられないようにする。
  # 変えられると、自分の組織の求人を他組織へ付け替えられる。
  attr_readonly :organization_id

  normalizes :title, with: ->(title) { title.strip }

  validates :status, inclusion: { in: STATUSES }
  validates :title, presence: true, length: { maximum: TITLE_MAX_LENGTH }
  validates :description, presence: true
  validates :employment_type, inclusion: { in: EMPLOYMENT_TYPES }, allow_blank: true

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  def draft?
    status == "draft"
  end
end
