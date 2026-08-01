# 個人情報を読んだ操作の記録。
#
# 情報が漏れた場合、誰が何を取得したかを追えないと範囲を確かめられない。
# 記録は後から変えられない。変えられる記録は、監査の役に立たない。
# 方針は docs/decisions/0047-access-audit-log.md を正本とする。
class AccessEvent < ApplicationRecord
  # 記録する操作。値をここで閉じる。
  ACTIONS = %w[
    candidate_profile_viewed
    job_application_viewed
    candidate_document_downloaded
    personal_data_exported
    candidate_search_performed
  ].freeze

  belongs_to :actor, class_name: "User", optional: true
  belongs_to :organization, optional: true

  attr_readonly :actor_id, :organization_id, :action, :subject_type, :subject_id,
                :subject_label, :ip_address

  validates :action, inclusion: { in: ACTIONS }
  validates :subject_type, presence: true
  validates :subject_label, presence: true

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  # 記録する。失敗は握り潰さない。
  # 「記録されているはず」と「実際に記録されている」が食い違う状態を作らない
  # （認証の記録（ADR 0010）と同じ扱い）。
  def self.record(action:, subject:, subject_label:, actor: nil, organization: nil, request: nil)
    create!(
      action: action,
      subject_type: subject.class.name,
      subject_id: subject.id,
      subject_label: subject_label,
      actor: actor,
      organization: organization,
      ip_address: request&.remote_ip
    )
  end
end
