require "test_helper"

# 添付を企業へ見せるかどうかの判定を検証する。
#
# 経路の側でも公開範囲を絞っているが、判定そのものを直接確かめる。
# 経路が増えたときに、この判定だけで正しく閉じている必要がある。
class CandidateProfileDocumentsTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email_address: "member@example.com", password: "correct horse battery")
    @candidate_profile = user.create_candidate_profile!(display_name: "山田 太郎")
  end

  test "公開範囲と添付の設定の両方が開いているときだけ、企業から取れる" do
    {
      [ "closed", false ] => false,
      [ "closed", true ] => false,
      [ "applied_organizations", true ] => false,
      [ "all_organizations", false ] => false,
      [ "all_organizations", true ] => true
    }.each do |(visibility, documents_visible), expected|
      @candidate_profile.update!(visibility: visibility, documents_visible: documents_visible)

      assert_equal expected, @candidate_profile.documents_visible_to_organizations?,
                   "#{visibility} / #{documents_visible}"
    end
  end

  test "受け付ける形式と大きさを固定する" do
    # 値を変えるときは、その理由を ADR 0031 へ書く。
    assert_equal "application/pdf", CandidateProfile::DOCUMENT_CONTENT_TYPE
    assert_equal 10.megabytes, CandidateProfile::DOCUMENT_MAX_BYTE_SIZE
    assert_equal %w[resume curriculum_vitae], CandidateProfile::DOCUMENT_KINDS
  end
end
