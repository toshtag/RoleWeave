# 企業側から求職者の添付を取る経路。
#
# 取れるのは、公開範囲が企業に開かれていて、かつ本人が添付を見せると
# 決めている場合だけである。判定はモデルの 1 か所が持つ。
# 方針は docs/decisions/0031-profile-documents.md を正本とする。
class Organizations::CandidateProfileDocumentsController < ApplicationController
  include OrganizationScope
  include DocumentDownload

  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_organization

  def show
    candidate_profile = CandidateProfile.visible_to(@organization).find(params[:candidate_profile_id])

    # 見せない設定の添付は、存在しない添付と同じ 404 とする。
    raise ActiveRecord::RecordNotFound unless candidate_profile.documents_visible_to?(@organization)

    send_document(candidate_profile.public_send(document_kind))
  end
end
