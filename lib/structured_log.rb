# 構造化ログの 1 行を組み立てる。
#
# 何を出すかをここ 1 か所で決める。出力する場所ごとに書くと、
# 出す項目が経路によって変わり、機械で読めなくなる。
#
# **個人情報を出さない。**メールアドレス・氏名・本文は含めない。
# ログは転送も保存もされ、公開範囲（ADR 0030）の設定が効かない。
# 方針は docs/decisions/0048-structured-logging.md を正本とする。
class StructuredLog
  # 出力するキー。すべて英語の snake_case とする。
  # 識別子は英語で書く（docs/development/language-policy.md）。
  def self.request(payload)
    {
      event: "request",
      controller: payload[:controller],
      action: payload[:action],
      method: payload[:method],
      path: path_without_query(payload[:path]),
      status: status_of(payload),
      duration_ms: round(payload[:duration]),
      db_ms: round(payload[:db_runtime]),
      view_ms: round(payload[:view_runtime]),
      # 利用者は id で表す。メールアドレスは出さない。
      user_id: payload[:user_id],
      exception: exception_class(payload[:exception]),
      exception_message: exception_message(payload[:exception])
    }.compact
  end

  def self.job(payload, event:)
    job = payload[:job]

    {
      event: event,
      job_class: job.class.name,
      queue: job.queue_name,
      job_id: job.job_id,
      duration_ms: round(payload[:duration]),
      exception: exception_class(payload[:exception_object]),
      exception_message: exception_message(payload[:exception_object])
    }.compact
  end

  # query string は出さない。絞り込みの条件に個人情報が入りうる。
  def self.path_without_query(path)
    path&.split("?")&.first
  end

  def self.status_of(payload)
    payload[:status] || (payload[:exception] ? 500 : nil)
  end

  def self.round(value)
    value&.round(1)
  end

  # 例外は種類とメッセージだけを出す。バックトレースは既定のログが持つ。
  def self.exception_class(exception)
    return nil if exception.blank?

    exception.is_a?(Array) ? exception.first : exception.class.name
  end

  def self.exception_message(exception)
    return nil if exception.blank?

    exception.is_a?(Array) ? exception.last : exception.message
  end

  private_class_method :path_without_query, :status_of, :round, :exception_class, :exception_message
end
