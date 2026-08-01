# 運営者の付与と剥奪。
#
# 画面からは付与できない。自己ホストの前提では、運営者は
# 「そのサーバーを運用している人」であり、サーバーへ入れることが前提になる。
namespace :roleweave do
  namespace :operator do
    desc "指定したメールアドレスのアカウントへ運営者権限を与える"
    task :grant, [ :email_address ] => :environment do |_task, args|
      puts change_operator(args[:email_address], true)
    end

    desc "指定したメールアドレスのアカウントから運営者権限を取り上げる"
    task :revoke, [ :email_address ] => :environment do |_task, args|
      puts change_operator(args[:email_address], false)
    end
  end
end

# 見つからないメールアドレスを黙って読み飛ばさない。
# 付与したつもりで付与されていない状態を作らない。
def change_operator(email_address, operator)
  abort "メールアドレスを指定してください" if email_address.blank?

  user = User.find_by(email_address: email_address)
  abort "アカウントが見つかりません: #{email_address}" if user.nil?

  user.update!(operator: operator)

  "#{user.email_address} の運営者権限: #{operator ? "付与" : "剥奪"}"
end
