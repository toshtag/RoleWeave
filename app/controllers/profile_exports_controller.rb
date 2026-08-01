# 利用者が自分のデータを持ち出す経路。
#
# 対象は常にログインしている本人とする。ID を受け取らない。
# 方針は docs/decisions/0032-personal-data-export.md を正本とする。
class ProfileExportsController < ApplicationController
  before_action :require_authentication
  before_action :require_confirmed_email

  def show
    export = ProfileExport.new(current_user)

    # ブラウザーの中で開かせず、ファイルとして保存させる。
    send_data export.to_json,
              filename: export.filename,
              type: "application/json",
              disposition: "attachment"
  end
end
