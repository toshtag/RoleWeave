# 組織が出す求人。
#
# 公開状態は 1 つのレコードが status として持つ。下書きと公開でレコードを分けない。
# 方針は docs/decisions/0016-job-posting-model.md を正本とする。
class JobPosting < ApplicationRecord
  TITLE_MAX_LENGTH = 200

  # 取り得る公開状態。値をここで閉じる。
  # 停止は後続タスクで足す。使い道のない状態を先に並べない。
  STATUSES = %w[draft pending_review published rejected].freeze

  # 許された遷移。ここにない組み合わせは通さない。
  #
  # 状態だけを増やして遷移を後回しにすると、どの状態からどこへ動けるかが
  # 経路ごとの判断になり、想定しない組み合わせが生まれる。
  # 詳細は docs/decisions/0017-job-posting-review.md を参照する。
  TRANSITIONS = {
    "draft" => %w[pending_review],
    "rejected" => %w[pending_review],
    "pending_review" => %w[published rejected]
  }.freeze

  # 編集できる状態。申請中と公開中の内容が、審査や公開の後で勝手に変わらないようにする。
  EDITABLE_STATUSES = %w[draft rejected].freeze

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

  def published?
    status == "published"
  end

  def editable?
    EDITABLE_STATUSES.include?(status)
  end

  def can_transition_to?(next_status)
    TRANSITIONS.fetch(status, []).include?(next_status)
  end

  # 状態を進める。許されていない遷移は false を返し、何も変えない。
  #
  # 例外にしないのは、画面から来る操作が競合しうるためである。
  # 承認と差し戻しが同時に届いたとき、後から来た方は失敗として扱えば足りる。
  def transition_to(next_status)
    return false unless can_transition_to?(next_status)

    update(status: next_status)
  end
end
