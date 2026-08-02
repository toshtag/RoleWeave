# 前段に置く逆プロキシの前提を、設定として読む。
#
# production は `config.assume_ssl` を置いている。
# これは「TLS を終端する逆プロキシが居る」という前提であり、
# `X-Forwarded-Proto` を無条件に信じる設定である。
#
# 一方で「**どのプロキシを信じるか**」を書かないと、
# `X-Forwarded-For` の値がそのまま `request.remote_ip` になる場合がある。
# レート制限（ADR 0044）も監査ログ（ADR 0047）も、その値を使う。
#
# 環境変数の読み方をここ 1 か所へ置く。
# 環境ごとの設定ファイルへ書くと、書式の検査が環境の数だけ増える。
# 方針は docs/decisions/0062-reverse-proxy-assumptions.md を正本とする。
class ReverseProxy
  # 設定の書式が不正であることを、起動の時点で伝える。
  class ConfigurationError < StandardError; end

  TRUSTED_PROXIES_KEY = "TRUSTED_PROXIES".freeze
  ALLOWED_HOSTS_KEY = "ALLOWED_HOSTS".freeze

  # 信じる前段のアドレス。IP アドレスまたは CIDR のカンマ区切りで受ける。
  #
  # 書かない場合は空を返す。Rails の既定（ループバックと私用の範囲）だけが
  # プロキシとして扱われ、いままでと同じ挙動になる。
  def self.trusted_proxies
    values(TRUSTED_PROXIES_KEY).map { |value| ip_range(value) }
  end

  # 受け入れるホスト名。カンマ区切りで受ける。
  #
  # 書かない場合は空を返す。`config.hosts` が空のままとなり、
  # いままでと同じく全ての Host を受け付ける。
  def self.allowed_hosts
    values(ALLOWED_HOSTS_KEY)
  end

  def self.values(key)
    ENV.fetch(key, "").split(",").filter_map { |value| value.strip.presence }
  end

  def self.ip_range(value)
    IPAddr.new(value)
  rescue IPAddr::InvalidAddressError
    # 黙って読み飛ばさない。読み飛ばすと、信じるつもりの前段が信じられていない
    # 状態のまま動き、レート制限が効かないことに気付けない。
    raise ConfigurationError, "#{TRUSTED_PROXIES_KEY} に IP アドレスでも CIDR でもない値がある: #{value}"
  end

  private_class_method :values, :ip_range
end
