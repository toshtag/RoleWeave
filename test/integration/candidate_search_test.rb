require "test_helper"

# 候補者の検索とタレントプールの契約を検証する。
#
# 検証対象は、**誰が探されるか**である。
# ここが緩むと、探されたくない人が一覧に並ぶ。
class CandidateSearchTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @recruiter = User.create!(email_address: "recruiter@example.com", password: PASSWORD).tap(&:confirm)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @recruiter)

    @candidate = User.create!(email_address: "candidate@example.com", password: PASSWORD).tap(&:confirm)
    @profile = @candidate.create_candidate_profile!(
      display_name: "山田 太郎", location: "東京", desired_occupation: "人事",
      visibility: "all_organizations", scout_opt_in: true
    )
    @profile.skills.create!(name: "採用計画")
  end

  test "受信の許可が既定で false である" do
    other = User.create!(email_address: "other@example.com", password: PASSWORD).tap(&:confirm)
    profile = other.create_candidate_profile!(display_name: "他の人")

    assert_not profile.scout_opt_in
  end

  test "許可した候補者だけが検索に出る" do
    other = User.create!(email_address: "other@example.com", password: PASSWORD).tap(&:confirm)
    other.create_candidate_profile!(display_name: "許可していない人", visibility: "all_organizations")
    sign_in_as(@recruiter)

    get search_path

    assert_response :success
    assert_select "main", text: /山田 太郎/
    assert_no_match(/許可していない人/, response.body)
  end

  test "公開範囲が closed の候補者は、許可していても出ない" do
    @profile.update!(visibility: "closed")
    sign_in_as(@recruiter)

    get search_path

    assert_no_match(/山田 太郎/, response.body)
  end

  test "組織に所属しない利用者は検索できない" do
    outsider = User.create!(email_address: "outsider@example.com", password: PASSWORD).tap(&:confirm)
    sign_in_as(outsider)

    get search_path

    assert_response :not_found
  end

  test "未ログインでは検索できない" do
    get search_path

    assert_redirected_to new_session_path(locale: :ja)
  end

  test "スキル・所在地・希望職種で絞り込める" do
    sign_in_as(@recruiter)

    get search_path(skill: "採用")

    assert_select "main", text: /山田 太郎/

    get search_path(skill: "存在しないスキル")

    assert_no_match(/山田 太郎/, response.body)

    get search_path(location: "大阪")

    assert_no_match(/山田 太郎/, response.body)

    get search_path(desired_occupation: "人事")

    assert_select "main", text: /山田 太郎/
  end

  test "スキルが名前の昇順で並ぶ" do
    # 並び順は関連の定義（CandidateProfile）が持つ。
    # 読み出す側で scope を付けると preload した結果を捨てて引き直すため、
    # 並び順をここで固定しておく（ADR 0049）。
    @profile.skills.create!(name: "評価設計")
    @profile.skills.create!(name: "英語")
    sign_in_as(@recruiter)

    get search_path

    assert_match(/採用計画 \/ 英語 \/ 評価設計/, response.body)
  end

  test "検索したことが監査ログに残る" do
    sign_in_as(@recruiter)

    assert_difference -> { AccessEvent.where(action: "candidate_search_performed").count }, 1 do
      get search_path(skill: "採用")
    end
  end

  test "結果には限られた項目だけが出る" do
    # 経歴の中身は、公開範囲が許すときに詳細で見る。
    @profile.update!(introduction: "秘密の自己紹介")
    @profile.work_experiences.create!(organization_name: "秘密の会社", position: "人事",
                                      started_on: Date.new(2020, 4, 1))
    sign_in_as(@recruiter)

    get search_path

    assert_no_match(/秘密の自己紹介/, response.body)
    assert_no_match(/秘密の会社/, response.body)
  end

  test "タレントプールを作り、候補者を出し入れできる" do
    sign_in_as(@recruiter)

    post organization_talent_pools_path(locale: :ja, organization_id: @organization),
         params: { name: "採用候補" }

    pool = TalentPool.sole

    assert_difference -> { TalentPoolMember.count }, 1 do
      post organization_talent_pool_members_path(locale: :ja, organization_id: @organization,
                                                 talent_pool_id: pool,
                                                 candidate_profile_id: @profile)
    end

    assert_difference -> { TalentPoolMember.count }, -1 do
      delete organization_talent_pool_member_path(locale: :ja, organization_id: @organization,
                                                  talent_pool_id: pool, id: TalentPoolMember.sole)
    end
  end

  test "同じ候補者を同じプールへ 2 回追加できない" do
    pool = @organization.talent_pools.create!(name: "採用候補")
    pool.talent_pool_members.create!(candidate_profile: @profile)
    sign_in_as(@recruiter)

    assert_no_difference -> { TalentPoolMember.count } do
      post organization_talent_pool_members_path(locale: :ja, organization_id: @organization,
                                                 talent_pool_id: pool,
                                                 candidate_profile_id: @profile)
    end
  end

  test "探せない候補者をプールへ入れられない" do
    @profile.update!(scout_opt_in: false)
    pool = @organization.talent_pools.create!(name: "採用候補")
    sign_in_as(@recruiter)

    post organization_talent_pool_members_path(locale: :ja, organization_id: @organization,
                                               talent_pool_id: pool,
                                               candidate_profile_id: @profile)

    assert_response :not_found
  end

  test "他組織のタレントプールを扱えない" do
    outsider = User.create!(email_address: "outsider@example.com", password: PASSWORD).tap(&:confirm)
    other_organization = Organization.create_with_owner!(name: "別の会社", user: outsider)
    pool = @organization.talent_pools.create!(name: "採用候補")
    sign_in_as(outsider)

    get organization_talent_pool_path(locale: :ja, organization_id: other_organization, id: pool)

    assert_response :not_found
  end

  test "プロフィールを削除するとプールからも消える" do
    pool = @organization.talent_pools.create!(name: "採用候補")
    pool.talent_pool_members.create!(candidate_profile: @profile)

    assert_difference -> { TalentPoolMember.count }, -1 do
      @profile.destroy
    end
  end

  test "求職者が受信の許可を切り替えられる" do
    sign_in_as(@candidate)

    patch profile_visibility_path(locale: :ja),
          params: { candidate_profile: { visibility: "all_organizations", scout_opt_in: "0" } }

    assert_not @profile.reload.scout_opt_in
  end

  test "受信の許可がエクスポートに含まれる" do
    assert_includes ProfileExport.new(@candidate).to_h[:candidate_profile].keys, "scout_opt_in"
  end

  test "検索とプールの画面を日本語と英語で表示する" do
    @organization.talent_pools.create!(name: "採用候補")
    sign_in_as(@recruiter)

    I18n.available_locales.each do |locale|
      get organization_candidate_searches_path(locale: locale, organization_id: @organization)

      assert_response :success
      assert_select "main h1", text: I18n.t("organizations.candidate_searches.index.title", locale: locale)

      get organization_talent_pools_path(locale: locale, organization_id: @organization)

      assert_response :success
    end
  end

  private
    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def search_path(conditions = {})
      organization_candidate_searches_path(locale: :ja, organization_id: @organization, **conditions)
    end
end
