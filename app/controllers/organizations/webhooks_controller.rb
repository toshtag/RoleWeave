# 外部への配信先を管理する経路。
#
# 管理できるのは組織の管理者だけとする。
# 配信先を差し替えられると、業務の出来事が別の相手へ届く。
# 方針は docs/decisions/0057-webhooks.md を正本とする。
class Organizations::WebhooksController < ApplicationController
  include OrganizationScope

  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_organization
  before_action :require_organization_owner

  def index
    @webhooks = @organization.webhooks.includes(:webhook_deliveries).recent
    @webhook = @organization.webhooks.build
  end

  def create
    webhook = @organization.webhooks.build(webhook_params)

    if webhook.save
      # 秘密はここでしか出さない。以後は画面に出さない。
      flash[:notice] = t(".created", secret: webhook.secret)
    else
      flash[:alert] = webhook.errors.full_messages.to_sentence
    end

    redirect_to organization_webhooks_path(locale: I18n.locale, organization_id: @organization)
  end

  def destroy
    @organization.webhooks.find(params[:id]).destroy!

    redirect_to organization_webhooks_path(locale: I18n.locale, organization_id: @organization)
  end

  private
    def webhook_params
      params.expect(webhook: [ :url, { event_kinds: [] } ])
            .tap { |permitted| permitted[:event_kinds] = Array(permitted[:event_kinds]).compact_blank }
    end
end
