# 添付ファイルを返す処理。
#
# 常に `Content-Disposition: attachment` で返し、ブラウザーの中で開かせない。
# 本人用と企業用の 2 つの経路が同じ規則に従う必要がある。
# 片方だけ変わると、そこから危険が戻る。
# 方針は docs/decisions/0031-profile-documents.md を正本とする。
module DocumentDownload
  extend ActiveSupport::Concern

  private
    def send_document(attachment)
      raise ActiveRecord::RecordNotFound unless attachment.attached?

      send_data attachment.download,
                filename: attachment.filename.to_s,
                type: attachment.content_type,
                disposition: "attachment"
    end

    # 種類は決まった 2 つだけとする。受け取った文字列をそのまま
    # `public_send` へ渡すと、ほかのメソッドを呼べてしまう。
    def document_kind
      CandidateProfile::DOCUMENT_KINDS.find { |kind| kind == params[:kind] } ||
        raise(ActiveRecord::RecordNotFound)
    end
end
