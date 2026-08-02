require "test_helper"

# アカウントの削除と匿名化の契約を検証する。
#
# 検証対象は、消せるかの判定と、消した後に何が残るかである。
class AccountDeletionTest < ActiveSupport::TestCase
  PASSWORD = "correct horse battery".freeze

  setup do
    @user = User.create!(email_address: "member@example.com", password: PASSWORD).tap(&:confirm)
  end

  test "組織に所属していないアカウントは削除できる" do
    assert_predicate AccountDeletion.new(@user), :deletable?
  end

  test "組織の唯一の管理者は削除できない" do
    # 管理者が 0 人になると、以後その組織で誰も招待も変更もできなくなる。
    organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @user)

    deletion = AccountDeletion.new(@user)

    assert_not_predicate deletion, :deletable?
    assert_equal [ organization ], deletion.sole_owner_organizations
  end

  test "管理者が 2 人いる組織の管理者は削除できる" do
    organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @user)
    another_owner = User.create!(email_address: "owner2@example.com", password: PASSWORD)
    organization.memberships.create!(user: another_owner, role: "owner", changed_by: @user)

    assert_predicate AccountDeletion.new(@user), :deletable?
  end

  test "判定は削除の時点で決まる" do
    # 画面を出した時点の答えを、削除の時点でも使わない。
    # 使うと、その間にもう 1 人の管理者が減っていても気付けない。
    organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @user)
    another_owner = User.create!(email_address: "owner2@example.com", password: PASSWORD)
    another_membership = organization.memberships.create!(user: another_owner, role: "owner",
                                                          changed_by: @user)
    deletion = AccountDeletion.new(@user)

    assert_predicate deletion, :deletable?

    another_membership.update_column(:role, "member")

    assert_raises(ActiveRecord::RecordNotDestroyed) { deletion.delete! }
    assert_equal 1, organization.memberships.where(role: "owner").count
  end

  test "一般の所属だけであれば削除できる" do
    organization = Organization.create_with_owner!(
      name: "サンプル株式会社",
      user: User.create!(email_address: "owner@example.com", password: PASSWORD)
    )
    organization.memberships.create!(user: @user, role: "member")

    assert_predicate AccountDeletion.new(@user), :deletable?
  end

  test "削除できないアカウントを消そうとすると止まる" do
    Organization.create_with_owner!(name: "サンプル株式会社", user: @user)

    assert_raises(ActiveRecord::RecordNotDestroyed) { AccountDeletion.new(@user).delete! }
    assert User.exists?(@user.id)
  end

  test "アカウントとプロフィールとログイン状態が消える" do
    @user.create_candidate_profile!(display_name: "山田 太郎")
    @user.sessions.create!

    AccountDeletion.new(@user).delete!

    assert_not User.exists?(@user.id)
    assert_equal 0, CandidateProfile.count
    assert_equal 0, Session.count
  end

  test "認証の記録は残り、メールアドレスだけが匿名化される" do
    # いつ何が起きたかまで消すと、削除の前後の調査ができなくなる。
    AuthenticationEvent.record(kind: "sign_in_succeeded", email_address: @user.email_address, user: @user)
    AuthenticationEvent.record(kind: "sign_in_failed", email_address: @user.email_address)

    assert_difference -> { AuthenticationEvent.count }, 0 do
      AccountDeletion.new(@user).delete!
    end

    assert_equal 0, AuthenticationEvent.where(email_address: "member@example.com").count
    assert_equal 2, AuthenticationEvent.where(email_address: AccountDeletion::ANONYMIZED_EMAIL_ADDRESS).count
  end

  test "匿名化に使うメールアドレスは実在しない領域を指す" do
    # 誰かの本物のメールアドレスと衝突しない。
    assert_match(/\.invalid\z/, AccountDeletion::ANONYMIZED_EMAIL_ADDRESS)
  end

  test "他人の認証の記録は書き換えない" do
    other = User.create!(email_address: "other@example.com", password: PASSWORD)
    AuthenticationEvent.record(kind: "sign_in_succeeded", email_address: other.email_address, user: other)
    AuthenticationEvent.record(kind: "sign_in_succeeded", email_address: @user.email_address, user: @user)

    AccountDeletion.new(@user).delete!

    assert_equal 1, AuthenticationEvent.where(email_address: "other@example.com").count
  end

  test "所属の履歴は残り、参照だけが空になる" do
    organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @user)
    another_owner = User.create!(email_address: "owner2@example.com", password: PASSWORD)
    organization.memberships.create!(user: another_owner, role: "owner", changed_by: @user)

    assert_difference -> { MembershipEvent.count }, 0 do
      AccountDeletion.new(@user).delete!
    end

    assert_nil MembershipEvent.where(organization: organization).first.user
  end

  test "添付も消える" do
    profile = @user.create_candidate_profile!(display_name: "山田 太郎")
    profile.resume.attach(io: File.open(Rails.root.join("test/fixtures/files/resume.pdf")),
                          filename: "resume.pdf", content_type: "application/pdf")

    assert_difference -> { ActiveStorage::Attachment.count }, -1 do
      AccountDeletion.new(@user).delete!
    end
  end
end
