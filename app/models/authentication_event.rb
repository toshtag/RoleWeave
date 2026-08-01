# 認証に関わる出来事の記録。
#
# 記録するのは「いつ、どのアカウントで、どこから、何が起きたか」までとする。
# パスワード、token、セッションの識別子は記録しない。
# 方針は docs/decisions/0010-authentication-events.md を正本とする。
class AuthenticationEvent < ApplicationRecord
  # 取り得る出来事。文字列で持ち、値をここで閉じる。
  # 自由な文字列を許すと、集計のたびに表記のゆれを吸収することになる。
  KINDS = %w[
    sign_in_succeeded
    sign_in_failed
    sign_out
    password_reset_completed
  ].freeze

  # アカウントは任意。存在しないメールアドレスへの試行は、どのアカウントのものでもない。
  belongs_to :user, optional: true

  # 検索は入力された値ではなく、正規化した値で行う。
  # User と同じ規則にそろえないと、同じ相手の記録が表記ごとに分かれる。
  normalizes :email_address, with: ->(email_address) { email_address.strip.downcase }

  validates :kind, inclusion: { in: KINDS }
  validates :email_address, presence: true

  # 出来事を記録する。
  #
  # 記録できなかったことを黙って捨てない。例外はそのまま呼び出し元へ返す。
  # 「記録されているはず」と「実際に記録されている」が食い違う状態を作らない。
  def self.record(kind:, email_address:, user: nil, request: nil)
    create!(
      kind: kind,
      email_address: email_address,
      user: user,
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent
    )
  end
end
