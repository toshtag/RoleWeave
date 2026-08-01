# 応募に紐づく会話の経路。
#
# 応募者と組織の所属者が同じ画面を使う。
# どちらから来ても、読めるかどうかの判定は 1 か所（Conversation.visible_to）が持つ。
# 方針は docs/decisions/0041-application-conversation.md を正本とする。
class ConversationsController < ApplicationController
  # 繰り返しの試行を抑える。上限と期間は ApplicationController が持つ。
  rate_limit to: MESSAGE_ATTEMPT_LIMIT, within: RATE_LIMIT_PERIOD, only: :create,
             with: -> { render_rate_limited }

  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_job_application

  def show
    @conversation = @job_application.conversation
    @messages = @conversation ? @conversation.messages.includes(:sender).chronological : []
    @message = Message.new

    # 開いた時点で、相手のメッセージを既読にする。
    @conversation&.mark_read_by(current_user)
  end

  def create
    # 関連を通した作成は、保存の後に外部キーを書き直すため、
    # 変更できない属性（attr_readonly）と衝突する。直接作る。
    @conversation = @job_application.conversation || Conversation.create!(job_application: @job_application)

    # 取り消された応募では新しいメッセージを送れない。読むことはできる。
    unless @conversation.open?
      flash[:alert] = t(".closed")

      return redirect_to application_conversation_path(locale: I18n.locale, application_id: @job_application)
    end

    @message = @conversation.messages.build(message_params.merge(sender: current_user))

    flash[:alert] = t(".invalid") unless @message.save

    redirect_to application_conversation_path(locale: I18n.locale, application_id: @job_application)
  end

  private
    # 参加者でなければ、存在しない応募と同じ 404 とする。
    # 分けると、その応募があることだけが分かる。
    def set_job_application
      @job_application = JobApplication.find(params[:application_id])

      raise ActiveRecord::RecordNotFound unless participant?
    end

    def participant?
      candidate = @job_application.candidate_profile.user_id == current_user.id
      member = @job_application.job_posting.organization.memberships.exists?(user_id: current_user.id)

      candidate || member
    end

    def message_params
      params.expect(message: [ :body ])
    end
end
