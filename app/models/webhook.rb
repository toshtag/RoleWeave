# 外部への配信先。
#
# どこへ送るかは利用者が決める。個別のサービス向けの実装は持たない（P14 の非目標）。
# **送る本文に個人情報を含めない。**送り先はこちらの管理下にない。
# 方針は docs/decisions/0057-webhooks.md を正本とする。
class Webhook < ApplicationRecord
  # 送れる出来事の種類。値をここで閉じる。
  EVENT_KINDS = %w[job_application_created job_application_stage_changed].freeze

  belongs_to :organization

  attr_readonly :organization_id

  has_many :webhook_deliveries, dependent: :destroy

  validates :url, presence: true, uniqueness: { scope: :organization_id }
  validates :secret, presence: true
  validate :url_is_http
  validate :event_kinds_are_known

  scope :enabled, -> { where(enabled: true) }
  scope :recent, -> { order(created_at: :desc, id: :desc) }

  # 秘密は自動で作る。利用者に考えさせない。
  before_validation :generate_secret, on: :create

  def self.for_event(organization, event_kind)
    enabled.where(organization: organization).select { |webhook| webhook.event_kinds.include?(event_kind) }
  end

  # 送り先が本物であることを確かめられるようにする。
  def signature_for(body)
    OpenSSL::HMAC.hexdigest("SHA256", secret, body)
  end

  private
    def generate_secret
      self.secret = SecureRandom.hex(32) if secret.blank?
    end

    # http/https に限る。file: や内部の別の仕組みを叩かせない。
    def url_is_http
      return if url.blank?

      scheme = URI.parse(url).scheme
      return if %w[http https].include?(scheme)

      errors.add(:url, :invalid_scheme)
    rescue URI::InvalidURIError
      errors.add(:url, :invalid_scheme)
    end

    def event_kinds_are_known
      unknown = event_kinds - EVENT_KINDS
      return if unknown.empty?

      errors.add(:event_kinds, :unknown)
    end
end
