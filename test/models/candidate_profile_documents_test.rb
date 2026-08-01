require "test_helper"

# 添付を企業へ見せるかどうかの判定を検証する。
#
# 経路の側でも公開範囲を絞っているが、判定そのものを直接確かめる。
# 経路が増えたときに、この判定だけで正しく閉じている必要がある。
class CandidateProfileDocumentsTest < ActiveSupport::TestCase
  PASSWORD = "correct horse battery".freeze

  setup do
    user = User.create!(email_address: "member@example.com", password: PASSWORD)
    @candidate_profile = user.create_candidate_profile!(display_name: "山田 太郎")

    recruiter = User.create!(email_address: "recruiter@example.com", password: PASSWORD)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: recruiter)
  end

  test "応募していない組織からは、公開範囲と添付の設定の両方が開いているときだけ取れる" do
    {
      [ "closed", false ] => false,
      [ "closed", true ] => false,
      # 応募していない組織には、applied_organizations は開かれていない。
      [ "applied_organizations", true ] => false,
      [ "all_organizations", false ] => false,
      [ "all_organizations", true ] => true
    }.each do |(visibility, documents_visible), expected|
      @candidate_profile.update!(visibility: visibility, documents_visible: documents_visible)

      assert_equal expected, @candidate_profile.documents_visible_to?(@organization),
                   "#{visibility} / #{documents_visible}"
    end
  end

  test "応募中の組織からは、applied_organizations でも取れる" do
    job_posting = @organization.job_postings.create!(
      title: "サンプルの求人", description: "仕事の内容", status: "published"
    )
    @candidate_profile.job_applications.create!(job_posting: job_posting)
    @candidate_profile.update!(visibility: "applied_organizations", documents_visible: true)

    assert @candidate_profile.documents_visible_to?(@organization)
  end

  test "受け付ける形式と大きさを固定する" do
    # 値を変えるときは、その理由を ADR 0031 へ書く。
    assert_equal "application/pdf", CandidateProfile::DOCUMENT_CONTENT_TYPE
    assert_equal 10.megabytes, CandidateProfile::DOCUMENT_MAX_BYTE_SIZE
    assert_equal %w[resume curriculum_vitae], CandidateProfile::DOCUMENT_KINDS
  end
end
