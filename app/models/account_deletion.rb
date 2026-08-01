# アカウントの削除と、削除に伴う匿名化の手順。
#
# 削除できるかの判定と、消し方を 1 か所へ置く。
# 経路が増えても、匿名化の書き忘れが起こらないようにする。
# 方針は docs/decisions/0033-account-deletion.md を正本とする。
class AccountDeletion
  # 匿名化した後に残す値。
  #
  # `.invalid` は、実在しないことが保証された予約済みのトップレベルドメインである
  # （RFC 2606）。誰かの本物のメールアドレスと衝突しない。
  ANONYMIZED_EMAIL_ADDRESS = "deleted@anonymized.invalid".freeze

  def initialize(user)
    @user = user
  end

  # 削除できないのは、その人がいなくなると
  # 管理者が 0 人になる組織がある場合だけとする。
  def deletable?
    sole_owner_organizations.empty?
  end

  # 理由を組織の名前で返す。「削除できません」だけでは、何をすればよいか分からない。
  def sole_owner_organizations
    @sole_owner_organizations ||= @user.organizations.select do |organization|
      owner_ids = organization.memberships.where(role: "owner").pluck(:user_id)

      owner_ids == [ @user.id ]
    end
  end

  # 削除と匿名化を同じトランザクションで行う。
  #
  # 片方だけが残ると、消えたアカウントのメールアドレスが記録に残る。
  def delete!
    raise ActiveRecord::RecordNotDestroyed, "組織の唯一の管理者は削除できない" unless deletable?

    ActiveRecord::Base.transaction do
      anonymize_authentication_events
      @user.destroy!
    end

    true
  end

  private
    # 記録そのものは残す。いつ何が起きたかまで消すと、
    # 削除の前後の調査ができなくなる。
    # 一方、メールアドレスが残れば個人は特定できる。値だけを置き換える。
    def anonymize_authentication_events
      AuthenticationEvent.where(user_id: @user.id)
                         .or(AuthenticationEvent.where(email_address: @user.email_address))
                         .update_all(email_address: ANONYMIZED_EMAIL_ADDRESS)
    end
end
