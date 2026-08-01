class User < ApplicationRecord
  # メールアドレスの上限。RFC 5321 が定める経路の最大長にそろえる。
  # 上限を持たないと、索引に載らない長さの値を受け付けてしまう。
  EMAIL_ADDRESS_MAX_LENGTH = 254

  # 形式の判定は Ruby 標準の正規表現に委ねる。
  # 独自の正規表現は、実在する書式を拒否する方向へ外れやすい。
  # 実際に届くかどうかは確認メールが確かめるものであり、ここでは判定しない。
  EMAIL_ADDRESS_FORMAT = URI::MailTo::EMAIL_REGEXP

  # 代入の時点で正規化する。
  #
  # 保存だけを正規化すると、find_by へ渡した値との比較が表記に依存する。
  # normalizes は検索条件にも同じ変換を適用するため、
  # 「登録できるが、そのままでは見つからない」状態が生まれない。
  normalizes :email_address, with: ->(email_address) { email_address.strip.downcase }

  validates :email_address,
            presence: true,
            length: { maximum: EMAIL_ADDRESS_MAX_LENGTH },
            format: { with: EMAIL_ADDRESS_FORMAT },
            uniqueness: true
end
