class User < ApplicationRecord
  # メールアドレスの上限。RFC 5321 が定める経路の最大長にそろえる。
  # 上限を持たないと、索引に載らない長さの値を受け付けてしまう。
  EMAIL_ADDRESS_MAX_LENGTH = 254

  # パスワードの最小長。
  #
  # 文字種の組み合わせは要求しない。組み合わせの強制は、
  # 記憶しやすい規則的な変形（末尾へ数字と記号を足す）を誘発し、
  # 長さを伸ばすほどには推測を難しくしない。
  PASSWORD_MIN_LENGTH = 12

  # bcrypt は 72 バイトを超える入力を切り捨てる。
  # 切り捨ての拒否は has_secure_password が行うため、ここでは値を写さず参照する。
  # 自前で 72 と書くと、Rails 側が変わったときに 2 つの上限が食い違う。
  PASSWORD_MAX_BYTESIZE = ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED

  # 形式の判定は Ruby 標準の正規表現に委ねる。
  # 独自の正規表現は、実在する書式を拒否する方向へ外れやすい。
  # 実際に届くかどうかは確認メールが確かめるものであり、ここでは判定しない。
  EMAIL_ADDRESS_FORMAT = URI::MailTo::EMAIL_REGEXP

  # 代入の時点で正規化する。
  #
  # 保存だけを正規化すると、find_by へ渡した値との比較が表記に依存する。
  # normalizes は検索条件にも同じ変換を適用するため、
  # 「登録できるが、そのままでは見つからない」状態が生まれない。
  # 確認リンクの有効期限。
  # 短すぎるとメールを見る前に切れ、長すぎると転送されたメールがいつまでも使える。
  EMAIL_CONFIRMATION_EXPIRES_IN = 24.hours

  # アカウントを削除したら、そのアカウントのログイン状態も残さない。
  has_many :sessions, dependent: :destroy

  # 確認リンクの token。
  #
  # データベースへ token を保存しない。保存すると、漏えいした時点で
  # そのまま使える文字列が残る。ここでは署名付きの値を都度作る。
  #
  # email_address を token へ含めることで、確認先を変えた時点で
  # 発行済みのリンクを使えなくする。
  generates_token_for :email_confirmation, expires_in: EMAIL_CONFIRMATION_EXPIRES_IN do
    email_address
  end

  normalizes :email_address, with: ->(email_address) { email_address.strip.downcase }

  # パスワードは復元できない形で保存する。
  # 平文は password_digest へ入らず、代入した属性もインスタンスの外へ出さない。
  #
  # 長さの検証は自前で持つ。既定の検証は 72 バイト超だけを見るため、
  # 短いパスワードをそのまま受け入れてしまう。
  has_secure_password validations: true

  validates :email_address,
            presence: true,
            length: { maximum: EMAIL_ADDRESS_MAX_LENGTH },
            format: { with: EMAIL_ADDRESS_FORMAT },
            uniqueness: true

  # 最小長だけを条件にする。
  #
  # 上限（bcrypt の 72 バイト）は has_secure_password が見るため重ねない。
  # 未入力のときも has_secure_password の存在検証が理由を伝える。
  validates :password,
            length: { minimum: PASSWORD_MIN_LENGTH },
            allow_nil: true

  def confirmed?
    confirmed_at.present?
  end

  # 確認を記録する。すでに確認済みなら何もしない。
  # 上書きすると、最初に確認した時刻が失われる。
  def confirm
    return true if confirmed?

    update_column(:confirmed_at, Time.current)
  end
end
