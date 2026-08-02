# 連携の実行の結果。
#
# 何件取り込めて、何件落ちたかを残す。
# 残さないと、「取り込んだつもり」しか分からない。
# 方針は docs/decisions/0058-csv-integration.md を正本とする。
class IntegrationRun < ApplicationRecord
  KINDS = %w[job_posting_import job_posting_export].freeze
  STATUSES = %w[completed failed].freeze

  belongs_to :organization
  belongs_to :performed_by, class_name: "User", optional: true

  attr_readonly :organization_id, :performed_by_id, :kind

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  def processed_count
    created_count + updated_count + failed_count
  end
end
