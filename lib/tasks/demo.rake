# 評価のためのデモデータ。
#
# development でのみ実行できる。架空データであることを、データそのものから分かるようにする。
# 方針は docs/decisions/0051-demo-data.md を正本とする。
namespace :roleweave do
  namespace :demo do
    desc "架空データのデモを投入する（development のみ）"
    task seed: :environment do
      puts DemoData.new.seed
      puts "ログインに使うパスワード: #{DemoData::PASSWORD}"
      puts "アカウント: #{DemoData::ACCOUNTS.values.map { |account| account[:email] }.join(', ')}"
    end

    desc "デモデータを消す（development のみ）"
    task clean: :environment do
      puts DemoData.new.clean
    end
  end
end
