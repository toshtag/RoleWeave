# 組織が出す求人。
#
# 公開状態は 1 つのレコードが status として持つ。下書きと公開でレコードを分けない。
# 方針は docs/decisions/0016-job-posting-model.md を正本とする。
class JobPosting < ApplicationRecord
  TITLE_MAX_LENGTH = 200

  # 取り得る公開状態。値をここで閉じる。
  STATUSES = %w[draft pending_review published rejected suspended].freeze

  # 許された遷移。ここにない組み合わせは通さない。
  #
  # 状態だけを増やして遷移を後回しにすると、どの状態からどこへ動けるかが
  # 経路ごとの判断になり、想定しない組み合わせが生まれる。
  # 詳細は docs/decisions/0017-job-posting-review.md を参照する。
  TRANSITIONS = {
    "draft" => %w[pending_review],
    "rejected" => %w[pending_review],
    "pending_review" => %w[published rejected],
    # 停止から直接公開へは戻さない。再公開も審査を通す。
    "published" => %w[suspended],
    "suspended" => %w[pending_review]
  }.freeze

  # 編集できる状態。申請中と公開中の内容が、審査や公開の後で勝手に変わらないようにする。
  EDITABLE_STATUSES = %w[draft rejected suspended].freeze

  # 雇用形態。自由記述にすると、公開側の絞り込みで表記のゆれを吸収することになる。
  EMPLOYMENT_TYPES = %w[full_time part_time contract internship].freeze

# 給与の通貨。1 つに固定できないため、求人ごとに持つ。
# 換算はしない。通貨をまたいだ比較は、為替の時点を決めないと成り立たない。
SALARY_CURRENCIES = %w[JPY USD EUR].freeze

  belongs_to :organization

  # 所属先の組織は、作成した後で変えられないようにする。
  # 変えられると、自分の組織の求人を他組織へ付け替えられる。
  attr_readonly :organization_id

  normalizes :title, with: ->(title) { title.strip }

  validates :status, inclusion: { in: STATUSES }
  validates :title, presence: true, length: { maximum: TITLE_MAX_LENGTH }
  validates :description, presence: true
  validates :employment_type, inclusion: { in: EMPLOYMENT_TYPES }, allow_blank: true

validates :salary_currency, inclusion: { in: SALARY_CURRENCIES }, allow_blank: true
validates :annual_salary_min, :annual_salary_max,
          numericality: { only_integer: true, greater_than_or_equal_to: 0 },
          allow_nil: true

validate :salary_range_is_ordered
validate :salary_amount_has_currency

  # 公開状態の変更を記録する。
  #
  # Controller ではなくモデルへ置く。状態を変える経路が増えても、
  # 記録の書き忘れが起こらない。
  after_create :record_created
  after_update :record_status_change, if: :saved_change_to_status?

  # 状態を変える主体。検証と記録のためだけに使い、保存はしない。
  attr_accessor :changed_by

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  # 公開側へ出せるのは公開中の求人だけとする。
  scope :published, -> { where(status: "published") }

  # キーワードの対象。ここへ列を足すと、そのまま検索の対象が広がる。
  SEARCHABLE_COLUMNS = %i[title description occupation location].freeze

  # キーワードによる部分一致。
  #
  # 日本語は PostgreSQL の標準機能だけでは語の区切りを判定できない。
  # 拡張を増やさない方針のため、初期の検索は部分一致とする。
  # 詳細は docs/decisions/0021-public-job-search.md を参照する。
  #
  # 語を空白で分け、すべての語を含む求人だけを返す。
  # いずれかを含む条件にすると、語を足すほど結果が増えて絞り込みにならない。
  scope :matching_keyword, ->(keyword) do
    words = keyword.to_s.split
    next all if words.empty?

    words.reduce(all) do |relation, word|
      # sanitize_sql_like は % と _ をそのままの文字として扱わせる。
      # これを外すと、利用者の入力が部分一致の記号として解釈される。
      pattern = "%#{sanitize_sql_like(word)}%"
      conditions = SEARCHABLE_COLUMNS.map { |column| arel_table[column].matches(pattern) }

      relation.where(conditions.reduce(:or))
    end
  end

  scope :matching_location, ->(location) do
    location.present? ? where(arel_table[:location].matches("%#{sanitize_sql_like(location)}%")) : all
  end

  scope :matching_occupation, ->(occupation) do
    occupation.present? ? where(arel_table[:occupation].matches("%#{sanitize_sql_like(occupation)}%")) : all
  end

# 給与の絞り込み。通貨と最低年収の組で使う。
#
# 通貨をまたいだ比較はしない。換算は為替の時点を決めないと成り立たない。
# 金額を持たない求人は、条件を指定したときに含めない。
# 「未記載」を「条件を満たす」と扱うと、結果が信用できなくなる。
scope :matching_minimum_salary, ->(currency, amount) do
  amount = amount.to_s.strip
  next all if amount.empty? || !SALARY_CURRENCIES.include?(currency)

  where(salary_currency: currency).where(arel_table[:annual_salary_min].gteq(amount.to_i))
end

  scope :matching_employment_type, ->(employment_type) do
    # 決められた値だけを受け付ける。それ以外は条件として無視する。
    EMPLOYMENT_TYPES.include?(employment_type) ? where(employment_type: employment_type) : all
  end

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

# 構造化された給与を持つか。表示と絞り込みの両方で使う。
def structured_salary?
  annual_salary_min.present? || annual_salary_max.present?
end

private
  def salary_range_is_ordered
    return if annual_salary_min.blank? || annual_salary_max.blank?
    return if annual_salary_max >= annual_salary_min

    errors.add(:annual_salary_max, :less_than_minimum)
  end

  def salary_amount_has_currency
    return unless structured_salary?
    return if salary_currency.present?

    errors.add(:salary_currency, :blank)
  end

  def record_created
      record_event(nil, status)
    end

    def record_status_change
      record_event(*saved_change_to_status)
    end

    def record_event(from_status, to_status)
      JobPostingEvent.create!(
        job_posting: self,
        organization: organization,
        changed_by: changed_by,
        from_status: from_status,
        to_status: to_status,
        job_posting_title: title
      )
    end
end
