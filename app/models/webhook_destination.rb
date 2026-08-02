# 外部への配信先の宛先。
#
# どこへ送るかは利用者が決める。決められるということは、
# **内部の宛先も書ける**ということである。
# アプリケーションのサーバーから出る接続は、外から出る接続とは届く範囲が違う。
# 自己ホストでは、データベースもジョブの実行基盤も同じネットワークに居る。
#
# 判定をここ 1 か所へ置く。登録の画面と配信のジョブで別々に書くと、
# 片方だけが緩んだ状態が生まれる。
# 方針は docs/decisions/0060-webhook-destination-restriction.md を正本とする。
class WebhookDestination
  # 判定を通らなかった宛先。配信の側で失敗として扱う。
  class Blocked < StandardError; end

  ALLOWED_SCHEMES = %w[http https].freeze

  # 拒否する範囲。値をここで閉じる。
  #
  # 「内部かどうか」を後から数え上げると、数え漏れがそのまま抜け道になる。
  # 用途の分かる名前を添えて、1 行ずつ書く。
  BLOCKED_RANGES = [
    # IPv4
    "0.0.0.0/8",          # このネットワーク
    "10.0.0.0/8",         # 私用
    "100.64.0.0/10",      # 事業者内の共有
    "127.0.0.0/8",        # ループバック
    "169.254.0.0/16",     # リンクローカル。クラウドのメタデータを含む
    "172.16.0.0/12",      # 私用
    "192.0.0.0/24",       # IETF の割り当て
    "192.0.2.0/24",       # 文書用
    "192.88.99.0/24",     # 6to4 の中継
    "192.168.0.0/16",     # 私用
    "198.18.0.0/15",      # 機器の試験
    "198.51.100.0/24",    # 文書用
    "203.0.113.0/24",     # 文書用
    "224.0.0.0/4",        # マルチキャスト
    "240.0.0.0/4",        # 予約済み。255.255.255.255 を含む
    # IPv6
    "::/128",             # 未指定
    "::1/128",            # ループバック
    "64:ff9b::/96",       # NAT64
    "100::/64",           # 破棄用
    "2001:db8::/32",      # 文書用
    "fc00::/7",           # ユニークローカル
    "fe80::/10",          # リンクローカル
    "fec0::/10",          # 旧サイトローカル。RFC 3879 で廃止されたが、配ってある分は残る
    "ff00::/8"            # マルチキャスト
  ].map { |range| IPAddr.new(range) }.freeze

  # 自己ホストでは、内部の受け口が正当な送り先である場合がある。
  # 明示したホスト名だけを例外とする。**既定は拒否とする。**
  def self.allowed_hosts
    ENV.fetch("WEBHOOK_ALLOWED_HOSTS", "").split(",").filter_map { |host| host.strip.downcase.presence }
  end

  def initialize(url)
    @url = url.to_s
  end

  # 登録の時点で分かる誤りを返す。誤りがなければ nil を返す。
  #
  # **名前は解決しない。**登録の時点で解決しても、配信の時点で同じ答えが返る
  # 保証はない。解決を配信の側へ寄せ、ここでは書かれた値だけを見る。
  # 名前を解決すると、DNS が落ちている間に登録できなくなる副作用だけが残る。
  def rejection
    return :invalid_scheme unless ALLOWED_SCHEMES.include?(uri&.scheme)
    return :invalid_scheme if uri.hostname.blank?
    return nil if explicitly_allowed?

    literal = ip_literal

    :internal_address if literal && blocked?(literal)
  end

  # 接続してよい IP を返す。明示して許した宛先では nil を返す。
  #
  # 名前をここで解決し、**解決した IP へ接続する**。
  # 解決した後にもう一度名前を引くと、その間に応答を変えられる（DNS rebinding）。
  #
  # 解決の結果が複数ある場合、そのすべてが許される場合だけ通す。
  # 1 つでも内部を指すなら、どれへ繋ぐかによって結果が変わる宛先である。
  def connect_address
    raise Blocked, rejection.to_s if rejection

    return nil if explicitly_allowed?

    addresses = resolve

    raise Blocked, "internal_address" if addresses.any? { |address| blocked?(address) }

    addresses.first.to_s
  end

  def uri
    @uri ||= URI.parse(@url)
  rescue URI::InvalidURIError
    nil
  end

  private
    def explicitly_allowed?
      self.class.allowed_hosts.include?(uri.hostname.downcase)
    end

    # 書かれた値がそのまま IP である場合だけ返す。名前であれば nil を返す。
    def ip_literal
      IPAddr.new(uri.hostname)
    rescue IPAddr::InvalidAddressError
      nil
    end

    def resolve
      Addrinfo.getaddrinfo(uri.hostname, uri.port, nil, :STREAM)
              .map { |addrinfo| IPAddr.new(addrinfo.ip_address) }
              .tap { |addresses| raise Blocked, "unresolvable" if addresses.empty? }
    rescue SocketError, IPAddr::InvalidAddressError
      raise Blocked, "unresolvable"
    end

    # IPv4 を写した IPv6（`::ffff:127.0.0.1`）は、元の IPv4 として判定する。
    # 写した形のまま比べると、同じ宛先が範囲の表に載っていない値になる。
    def blocked?(address)
      native = address.ipv4_mapped? ? address.native : address

      BLOCKED_RANGES.any? { |range| range.include?(native) }
    end
end
