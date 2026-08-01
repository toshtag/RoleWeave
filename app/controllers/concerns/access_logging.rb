# 個人情報を読んだ操作を記録する。
#
# 記録の作り方を 1 か所に保つ。経路ごとに書くと、書き方が分かれる。
# 見えなかった場合（404）は記録しない。読めていない操作は「読んだ」ではない。
# 方針は docs/decisions/0047-access-audit-log.md を正本とする。
module AccessLogging
  extend ActiveSupport::Concern

  private
    def record_access(action, subject:, subject_label:, organization: nil)
      AccessEvent.record(
        action: action,
        subject: subject,
        subject_label: subject_label,
        actor: current_user,
        organization: organization,
        request: request
      )
    end
end
