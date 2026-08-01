# 求職者が自分の履歴書・職務経歴書を扱う経路。
#
# 配信は Active Storage の署名付き URL ではなく、この経路から行う。
# 署名付き URL は、それを知っていれば誰でも開ける。
# 個人の履歴書をその形で配ると、URL が渡った先すべてから読める。
# 方針は docs/decisions/0031-profile-documents.md を正本とする。
class ProfileDocumentsController < ApplicationController
  include CandidateProfileScope
  include DocumentDownload

  def edit
  end

  def update
    if @candidate_profile.update(document_params)
      redirect_to edit_profile_documents_path(locale: I18n.locale)
    else
      render :edit, status: :unprocessable_content
    end
  end

  # 本人によるダウンロード。
  def show
    send_document(@candidate_profile.public_send(document_kind))
  end

  def destroy
    @candidate_profile.public_send(document_kind).purge

    redirect_to edit_profile_documents_path(locale: I18n.locale)
  end

  private
    def document_params
      params.expect(candidate_profile: CandidateProfile::DOCUMENT_KINDS.map(&:to_sym))
    end
end
