require "test_helper"

# 外部への配信先の宛先の判定の契約を検証する。
#
# 検証対象は、内部を指す宛先を通さないことと、
# 判定と接続の間に答えが変わっても内部へ繋がないことである。
class WebhookDestinationTest < ActiveSupport::TestCase
  test "http と https だけを受け入れる" do
    assert_nil WebhookDestination.new("https://example.com/hook").rejection
    assert_nil WebhookDestination.new("http://example.com/hook").rejection
    assert_equal :invalid_scheme, WebhookDestination.new("file:///etc/passwd").rejection
    assert_equal :invalid_scheme, WebhookDestination.new("ftp://example.com").rejection
    assert_equal :invalid_scheme, WebhookDestination.new("gopher://example.com").rejection
    assert_equal :invalid_scheme, WebhookDestination.new("http://").rejection
  end

  test "ループバックを拒否する" do
    assert_equal :internal_address, WebhookDestination.new("http://127.0.0.1/hook").rejection
    assert_equal :internal_address, WebhookDestination.new("http://127.99.1.2:5432/").rejection
    assert_equal :internal_address, WebhookDestination.new("http://[::1]/hook").rejection
  end

  test "クラウドのメタデータの宛先を拒否する" do
    assert_equal :internal_address, WebhookDestination.new("http://169.254.169.254/latest/").rejection
  end

  test "私用の範囲を拒否する" do
    [ "http://10.0.0.5:8080/", "http://172.16.0.1/", "http://172.31.255.254/",
      "http://192.168.1.1/", "http://[fc00::1]/", "http://[fd12:3456::1]/" ].each do |url|
      assert_equal :internal_address, WebhookDestination.new(url).rejection, url
    end
  end

  test "その他の予約された範囲を拒否する" do
    [ "http://0.0.0.0/", "http://100.64.0.1/", "http://[fe80::1]/",
      "http://224.0.0.1/", "http://255.255.255.255/", "http://[::]/" ].each do |url|
      assert_equal :internal_address, WebhookDestination.new(url).rejection, url
    end
  end

  test "旧サイトローカルの範囲を拒否する" do
    # fec0::/10 は RFC 3879 で廃止された。ただし廃止は、既に配ってある
    # アドレスを消して回るものではない。内部でこの範囲を配っている環境は残る。
    # 範囲の端まで確かめる。fe80::/10 は febf:: までで切れており、ここは含まない。
    [ "http://[fec0::1]/", "http://[fedc::1]/", "http://[feff::1]/" ].each do |url|
      assert_equal :internal_address, WebhookDestination.new(url).rejection, url
    end
  end

  test "IPv4 を写した IPv6 も元の IPv4 として判定する" do
    # 写した形のまま比べると、同じ宛先が範囲の表に載っていない値になる。
    assert_equal :internal_address, WebhookDestination.new("http://[::ffff:127.0.0.1]/").rejection
    assert_equal :internal_address, WebhookDestination.new("http://[::ffff:10.0.0.1]/").rejection
  end

  test "外部の IP は通す" do
    assert_nil WebhookDestination.new("http://93.184.216.34/hook").rejection
    assert_nil WebhookDestination.new("http://[2606:2800:220:1::1]/hook").rejection
  end

  test "名前の宛先は登録の時点では解決しない" do
    # 登録の時点で解決しても、配信の時点で同じ答えが返る保証はない。
    # DNS が落ちている間に登録できなくなる副作用だけが残る。
    assert_nil WebhookDestination.new("https://example.invalid/hook").rejection
  end

  test "配信の時点で接続してよい IP を返す" do
    assert_equal "93.184.216.34", WebhookDestination.new("http://93.184.216.34/hook").connect_address
  end

  test "名前が内部の IP へ解決される宛先は配信の時点で拒む" do
    error = assert_raises(WebhookDestination::Blocked) do
      WebhookDestination.new("http://localhost/hook").connect_address
    end

    assert_equal "internal_address", error.message
  end

  test "名前の解決の結果に旧サイトローカルが混ざれば配信の時点で拒む" do
    # 1 つでも内部を指すなら、どれへ繋ぐかによって結果が変わる宛先である。
    resolving("93.184.216.34", "fec0::1") do
      error = assert_raises(WebhookDestination::Blocked) do
        WebhookDestination.new("http://example.com/hook").connect_address
      end

      assert_equal "internal_address", error.message
    end
  end

  test "解決できない名前は配信の時点で拒む" do
    error = assert_raises(WebhookDestination::Blocked) do
      WebhookDestination.new("https://example.invalid/hook").connect_address
    end

    assert_equal "unresolvable", error.message
  end

  test "登録の時点で拒む宛先は配信の時点でも拒む" do
    error = assert_raises(WebhookDestination::Blocked) do
      WebhookDestination.new("http://127.0.0.1/hook").connect_address
    end

    assert_equal "internal_address", error.message
  end

  test "明示して許したホスト名は内部でも通す" do
    # 自己ホストでは、内部の受け口が正当な送り先である場合がある。
    allowing("internal.example.test") do
      assert_nil WebhookDestination.new("http://internal.example.test/hook").rejection
    end
  end

  test "明示して許したホスト名では名前のまま繋ぐ" do
    allowing("internal.example.test") do
      assert_nil WebhookDestination.new("http://internal.example.test/hook").connect_address
    end
  end

  test "明示していないホスト名は許さない" do
    allowing("internal.example.test") do
      assert_equal :internal_address, WebhookDestination.new("http://127.0.0.1/hook").rejection
    end
  end

  private
    # 名前の解決の結果を差し替える。
    #
    # fec0::/10 へ解決される実在の名前はないため、解決の側を置き換えるほかない。
    # 実際のネットワークへは繋がない。判定だけを見る。
    def resolving(*ip_addresses)
      original = Addrinfo.method(:getaddrinfo)
      Addrinfo.define_singleton_method(:getaddrinfo) do |*|
        ip_addresses.map { |ip_address| Addrinfo.ip(ip_address) }
      end

      yield
    ensure
      Addrinfo.define_singleton_method(:getaddrinfo, original)
    end

    def allowing(hosts)
      original = ENV["WEBHOOK_ALLOWED_HOSTS"]
      ENV["WEBHOOK_ALLOWED_HOSTS"] = hosts

      yield
    ensure
      ENV["WEBHOOK_ALLOWED_HOSTS"] = original
    end
end
