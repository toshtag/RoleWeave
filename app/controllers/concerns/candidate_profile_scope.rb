# プロフィールへ従属する情報（職歴・学歴・スキル）を扱う経路の共通部分。
#
# 対象は常に本人のプロフィールを起点に引く。
# ID から直接引くと、他人の経歴も引けてしまう。
# 方針は docs/decisions/0026-candidate-profile.md を正本とする。
module CandidateProfileScope
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    before_action :require_confirmed_email
    before_action :set_candidate_profile
  end

  private
    def set_candidate_profile
      @candidate_profile = current_user.candidate_profile

      # プロフィールがなければ、経歴の置き場所がない。作成の画面へ送る。
      redirect_to new_profile_path(locale: I18n.locale) if @candidate_profile.nil?
    end
end
