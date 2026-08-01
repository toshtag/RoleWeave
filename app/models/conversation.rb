# 応募に紐づく会話。
#
# 相手は応募によって決まる。応募者本人と、その求人を出した組織の所属者である。
# 相手を自由に選べる仕組みにすると、応募と関係のない連絡が発生する。
# 方針は docs/decisions/0041-application-conversation.md を正本とする。
class Conversation < ApplicationRecord
  belongs_to :job_application

  attr_readonly :job_application_id

  has_many :messages, dependent: :destroy

  validates :job_application_id, uniqueness: true

  # 会話を読める利用者は、ここだけで決める。
  # 経路ごとに条件を書くと、書き忘れた経路が他人の連絡への入口になる。
  scope :visible_to, ->(user) {
    joins(job_application: [ :candidate_profile, { job_posting: :organization } ])
      .where(candidate_profiles: { user_id: user.id })
      .or(
        joins(job_application: [ :candidate_profile, { job_posting: :organization } ])
          .where(job_postings: { organization_id: user.organizations.select(:id) })
      )
  }

  # 応募者本人か、その組織の所属者か。
  def participant?(user)
    candidate?(user) || organization_member?(user)
  end

  def candidate?(user)
    job_application.candidate_profile.user_id == user.id
  end

  def organization_member?(user)
    job_application.job_posting.organization.memberships.exists?(user_id: user.id)
  end

  # 取り消された応募では、新しいメッセージを送れない。
  # 読むことはできる。やり取りは選考の記録である。
  def open?
    job_application.submitted?
  end

  # 自分が送っていない、まだ読んでいないメッセージの数。
  def unread_count_for(user)
    messages.where.not(sender_id: user.id)
            .where.not(id: MessageRead.where(user_id: user.id).select(:message_id))
            .count
  end

  # 開いた時点で、相手のメッセージを既読にする。
  def mark_read_by(user)
    unread = messages.where.not(sender_id: user.id)
                     .where.not(id: MessageRead.where(user_id: user.id).select(:message_id))

    unread.find_each { |message| MessageRead.create!(message: message, user: user) }
  end
end
