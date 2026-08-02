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
  #
  # **結果を保持しない。**判定は、呼んだ時点の owner の数で決まる。
  # 保持すると、画面を出した時点の答えを削除の時点でも使うことになり、
  # その間に owner が減っていても気付けない。
  def sole_owner_organizations
    @user.organizations.select do |organization|
      owner_ids = organization.memberships.where(role: "owner").pluck(:user_id)

      owner_ids == [ @user.id ]
    end
  end

  # 削除と匿名化を同じトランザクションで行う。
  #
  # 片方だけが残ると、消えたアカウントのメールアドレスが記録に残る。
  #
  # 判定もこのトランザクションの中で行う。
  # 外で判定すると、判定してから削除するまでの間に別の owner が減りうる。
  # 2 人の owner が同時に自分を削除すると、どちらも「もう 1 人いる」と判断し、
  # 組織の owner が 0 人になる（`Membership#update_within_owner_invariant` と同じ不変条件）。
  def delete!
    ActiveRecord::Base.transaction do
      lock_organizations

      raise ActiveRecord::RecordNotDestroyed, "組織の唯一の管理者は削除できない" unless deletable?

      anonymize_authentication_events
      @user.destroy!
    end

    true
  end

  private
    # 所属する組織の行を押さえる。
    #
    # id の昇順で 1 つずつ押さえる。順序を決めておかないと、
    # 複数の組織に所属する利用者が同時に消えるときへ互いを待ち合わせる。
    def lock_organizations
      @user.memberships.pluck(:organization_id).sort.each do |organization_id|
        Organization.lock.find(organization_id)
      end
    end

    # 記録そのものは残す。いつ何が起きたかまで消すと、
    # 削除の前後の調査ができなくなる。
    # 一方、メールアドレスが残れば個人は特定できる。値だけを置き換える。
    def anonymize_authentication_events
      AuthenticationEvent.where(user_id: @user.id)
                         .or(AuthenticationEvent.where(email_address: @user.email_address))
                         .update_all(email_address: ANONYMIZED_EMAIL_ADDRESS)
    end
end
