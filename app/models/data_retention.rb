# データの保持期限と、期限を過ぎたときの扱い。
#
# 期限を決めないと、個人情報を含む記録が無期限に残る。
# 一方、記録には残す理由がある（監査・選考の経緯）。一律に消すと、その理由が失われる。
# 表ごとに「どれだけ残すか」と「どう消すか」を決め、ここ 1 か所に置く。
# 方針は docs/decisions/0046-data-retention.md を正本とする。
class DataRetention
  # 期限を過ぎたときの扱い。
  #
  # :delete は行ごと消す。:anonymize は行を残し、個人を特定できる値だけを置き換える。
  POLICIES = {
    "sessions" => {
      model: -> { Session },
      period: 90.days,
      strategy: :delete,
      reason: "ログイン状態の記録。期限が過ぎたものは再利用されない"
    },
    "notifications" => {
      model: -> { Notification },
      period: 180.days,
      strategy: :delete,
      reason: "読んだ後の通知を残す理由がない。中身は元の記録が持つ"
    },
    "access_events" => {
      model: -> { AccessEvent },
      period: 1.year,
      strategy: :delete,
      reason: "読んだ操作の記録。漏えいの調査に使う期間を過ぎたら残さない"
    },
    "authentication_events" => {
      model: -> { AuthenticationEvent },
      period: 1.year,
      strategy: :anonymize,
      reason: "いつ何が起きたかは監査に要る（ADR 0010）。メールアドレスだけを置き換える"
    }
  }.freeze

  # 対象にしない表と、その理由。
  #
  # 「まだ決めていない」ではなく「決めた結果、対象にしない」を書く。
  EXCLUDED_TABLES = {
    "users" => "本人の削除（ADR 0033）で消える。期限で勝手に消さない",
    "candidate_profiles" => "本人の削除で消える。応募の途中で消えると選考が壊れる",
    "work_experiences" => "プロフィールに従属する",
    "educations" => "プロフィールに従属する",
    "skills" => "プロフィールに従属する",
    "desired_conditions" => "プロフィールに従属する",
    "saved_job_postings" => "求職者が自分で保存したもの。プロフィールの削除で消える",
    "saved_searches" => "求職者が自分で保存したもの。プロフィールの削除で消える",
    "scouts" => "送った記録。組織またはプロフィールの削除で消える",
    "scout_templates" => "企業の下書き。組織の削除で消える",
    "scout_blocks" => "候補者が止めた記録。止めたままにする",
    "talent_pools" => "企業が保存したもの。組織の削除で消える",
    "talent_pool_members" => "プロフィールまたはプールの削除で消える",
    "organizations" => "組織の削除の経路がまだない",
    "memberships" => "現在の所属であり、期限で消す対象ではない",
    "invitations" => "受諾されない招待は token の期限で無効になる",
    "job_postings" => "求人は組織の資産である。期限で消さない",
    "job_applications" => "応募は選考の記録である。プロフィールの削除で消える",
    "conversations" => "応募に従属する",
    "messages" => "やり取りは選考の記録である。応募の削除で消える",
    "message_reads" => "メッセージに従属する",
    "application_reviews" => "選考の判断の記録であり、応募に従属する",
    "interview_schedules" => "選考の経緯であり、応募に従属する",
    "membership_events" => "権限の変更の履歴。参照は削除時に空になる（ADR 0014）",
    "job_posting_events" => "公開状態の履歴。参照は削除時に空になる（ADR 0018）",
    "job_application_events" => "応募の記録。参照が消えても残す（ADR 0037）",
    "active_storage_attachments" => "添付の実体に従属する",
    "active_storage_blobs" => "添付の実体。purge で消える（ADR 0031）",
    "active_storage_variant_records" => "変換した画像を作っていない"
  }.freeze

  def initialize(now: Time.current)
    @now = now
  end

  # 期限を過ぎた件数を数えるだけで、何も変えない。
  def report
    POLICIES.transform_values { |policy| expired(policy).count }
  end

  # 期限を過ぎたものを、決めた方法で処理する。
  def apply
    POLICIES.to_h do |table, policy|
      count = case policy.fetch(:strategy)
      when :delete then expired(policy).delete_all
      when :anonymize then anonymize(table, expired(policy))
      else raise ArgumentError, "未知の扱い: #{policy.fetch(:strategy)}"
      end

      [ table, count ]
    end
  end

  private
    def expired(policy)
      policy.fetch(:model).call.where(created_at: ...(@now - policy.fetch(:period)))
    end

    # 行は残し、個人を特定できる値だけを置き換える。
    def anonymize(table, scope)
      raise ArgumentError, "匿名化の方法が決まっていない: #{table}" unless table == "authentication_events"

      scope.where.not(email_address: AccountDeletion::ANONYMIZED_EMAIL_ADDRESS)
           .update_all(email_address: AccountDeletion::ANONYMIZED_EMAIL_ADDRESS, user_id: nil)
    end
end
