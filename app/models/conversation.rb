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
    unread_messages_for(user).count
  end

  # 開いた時点で、相手のメッセージを既読にする。
  #
  # 1 回の書き込みでまとめる。1 通ずつ作ると、未読の数だけ
  # 検証の SELECT と INSERT が往復する。
  def mark_read_by(user)
    rows = unread_messages_for(user).pluck(:id).map do |message_id|
      { message_id: message_id, user_id: user.id }
    end

    # insert_all はモデルの検証もコールバックも通らない。
    # 作成時刻と更新時刻だけは Rails が入れる（`record_timestamps`）。
    # 空の配列は問い合わせを出さずに戻るため、ここで分岐しない。
    #
    # 二重の記録は一意索引に任せる。同じ会話を同時に開いた場合に起こりうる。
    MessageRead.insert_all(rows, unique_by: %i[message_id user_id])
  end

  private
    # 自分が送っていない、まだ読んでいないメッセージ。
    #
    # 数えるときも既読にするときも、同じ判定を使う。2 か所へ書くと、
    # 数えた未読と既読にした未読が食い違いうる。
    #
    # `NOT EXISTS` で書く。`NOT IN` の副問い合わせは anti-join へ書き換えられず、
    # **その利用者が読んだすべてのメッセージ**を毎回組み立てることになる。
    # 会話の中には限られないため、読むほど重くなる。
    # `message_reads` の `(message_id, user_id)` の一意索引が、そのまま使える。
    def unread_messages_for(user)
      read_by_user = MessageRead.where(user_id: user.id)
                                .where(MessageRead.arel_table[:message_id].eq(Message.arel_table[:id]))

      messages.where.not(sender_id: user.id).where.not(read_by_user.arel.exists)
    end
end
