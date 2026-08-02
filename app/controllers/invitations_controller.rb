class InvitationsController < ApplicationController
  include OrganizationScope

  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_organization, only: %i[new create]
  # 招待できるのは管理者だけとする。入ったばかりのメンバーが
  # 誰でも他の人を招待できる状態にしない。
  before_action :require_organization_owner, only: %i[new create]

  # 任意の宛先へメールを積める経路である。
  #
  # 同じ組織から同じ宛先への未受諾の招待には一意制約があるが、
  # **宛先を変えれば何度でも作れる。**組織も確認済みのアカウントであれば作れるため、
  # 組織ごとに数えると、作り直すだけで迂回できる。
  # 数える単位は IP とする（ADR 0044）。組織を切り替えても変わらない。
  #
  # **認可の後に置く。**Rails は宣言した位置へ before_action を登録するため、
  # 認証より前に書くと、認証・認可を通らない要求まで枠を数えることになる。
  # 枠は IP 単位で共有される。減らされた側の管理者は招待を作れなくなる。
  # 数えるのは、上の 4 つの before_action を通った要求である。
  # 通った後は、入力の検証に失敗した要求も数える。
  rate_limit to: INVITATION_ATTEMPT_LIMIT, within: RATE_LIMIT_PERIOD, only: :create,
             with: -> { render_rate_limited }

  def new
    @invitation = @organization.invitations.new
  end

  def create
    @invitation = @organization.invitations.new(invitation_params.merge(invited_by: current_user))

    if @invitation.save
      OrganizationMailer.invitation(@invitation, locale: I18n.locale).deliver_later

      redirect_to organizations_path(locale: I18n.locale)
    else
      render :new, status: :unprocessable_content
    end
  end

  # 受諾。メールのリンクは GET にしかできない。
  def show
    invitation = Invitation.find_by_token_for(:acceptance, params[:token])

    # token が壊れている、期限切れ、宛先の変更後、受諾済みのいずれかである。
    # どれであるかを画面で区別しない。区別すると、token を試す手がかりになる。
    return render :invalid, status: :unprocessable_content if invitation.nil?

    # 招待された宛先と同じアカウントでなければ受け入れない。
    # 受け入れると、リンクを手にした別人が組織へ入れてしまう。
    return render :mismatched, status: :forbidden unless invitation.email_address == current_user.email_address

    invitation.accept!(current_user)

    redirect_to organizations_path(locale: I18n.locale)
  end

  private
    def invitation_params
      params.expect(invitation: %i[email_address role])
    end
end
