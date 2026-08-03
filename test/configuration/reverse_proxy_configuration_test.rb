require "test_helper"

# 逆プロキシの前提の設定の契約を検証する。
#
# production の設定は test 環境では読み込まれない。
# 値そのものは `ReverseProxyTest` が確かめる。ここで確かめるのは、
# **その値が production の設定へ繋がっていること**である。
# 繋ぎを外しても値の検証は通るため、繋ぎの側を別に固定する。
class ReverseProxyConfigurationTest < ActiveSupport::TestCase
  PRODUCTION_ENVIRONMENT = Rails.root.join("config/environments/production.rb")

  setup do
    @source = PRODUCTION_ENVIRONMENT.read
  end

  test "信じる前段を設定へ渡す" do
    assert_match(/ReverseProxy\.trusted_proxies/, @source)
    assert_match(/config\.action_dispatch\.trusted_proxies\s*=/, @source)
  end

  test "受け入れるホスト名を設定へ渡す" do
    assert_match(/config\.hosts\s*\+=\s*ReverseProxy\.allowed_hosts/, @source)
  end

  test "受け入れるホスト名を置き換えではなく追加で渡す" do
    # 置き換えにすると、Rails が足す既定の項目を落とす。
    assert_no_match(/config\.hosts\s*=\s*ReverseProxy/, @source)
  end

  test "稼働確認の経路を名前の検証から除く" do
    # 監視は名前ではなく IP で叩く構成がある。
    # 生成時のコメントに同じ行があると、それを拾ってしまう。
    # 効いている行だけを見るため、コメントを除いてから探す。
    assert_match(%r{config\.host_authorization\s*=.*/up}, effective_source)
  end

  test "設定を 2 か所に書かない" do
    # どちらが効いているのかが読めなくなる。
    assert_equal 1, @source.scan(/config\.host_authorization/).size
    assert_equal 1, @source.scan(/config\.hosts/).size
  end

  test "逆プロキシの前提が文書化されている" do
    # 設定できることと、設定しないと何が効かないかは、運用の側が読む。
    assert_predicate Rails.root.join("docs/operations/reverse-proxy.md"), :exist?
  end

  private
    # コメントを除いた行だけを返す。
    def effective_source
      @source.lines.reject { |line| line.strip.start_with?("#") }.join
    end
end
