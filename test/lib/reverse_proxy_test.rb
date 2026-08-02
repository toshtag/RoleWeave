require "test_helper"

# 逆プロキシの前提の読み取りの契約を検証する。
#
# 検証対象は、書いた値がそのまま設定になることと、
# 書かない場合の挙動が変わらないことである。
class ReverseProxyTest < ActiveSupport::TestCase
  test "書かない場合は空を返す" do
    # 空であれば Rails の既定のままとなり、いままでと同じ挙動になる。
    with_env(nil, nil) do
      assert_empty ReverseProxy.trusted_proxies
      assert_empty ReverseProxy.allowed_hosts
    end
  end

  test "信じる前段を CIDR で受ける" do
    with_env("10.0.0.0/8", nil) do
      proxies = ReverseProxy.trusted_proxies

      assert_equal 1, proxies.size
      assert_includes proxies.first, IPAddr.new("10.5.5.5")
      assert_not_includes proxies.first, IPAddr.new("11.0.0.1")
    end
  end

  test "信じる前段を複数受ける" do
    with_env("10.0.0.0/8, 192.168.1.5 ,", nil) do
      assert_equal 2, ReverseProxy.trusted_proxies.size
    end
  end

  test "IP でも CIDR でもない値は起動の時点で失敗する" do
    # 黙って読み飛ばすと、信じるつもりの前段が信じられていない状態のまま動く。
    with_env("not-an-ip", nil) do
      error = assert_raises(ReverseProxy::ConfigurationError) { ReverseProxy.trusted_proxies }

      assert_match(/not-an-ip/, error.message)
    end
  end

  test "受け入れるホスト名を受ける" do
    with_env(nil, "app.example.com, www.example.com , ") do
      assert_equal %w[app.example.com www.example.com], ReverseProxy.allowed_hosts
    end
  end

  private
    def with_env(trusted_proxies, allowed_hosts)
      original = ENV.values_at("TRUSTED_PROXIES", "ALLOWED_HOSTS")
      ENV["TRUSTED_PROXIES"] = trusted_proxies
      ENV["ALLOWED_HOSTS"] = allowed_hosts

      yield
    ensure
      ENV["TRUSTED_PROXIES"], ENV["ALLOWED_HOSTS"] = original
    end
end
