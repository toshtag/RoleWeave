module ApplicationHelper
  # 項目ごとの誤りの説明へ与える id。
  #
  # 誤りがない項目では nil を返す。存在しない id を aria-describedby へ書くと、
  # 支援技術が解決できない参照になる。
  def field_error_id(record, attribute)
    return if record.errors[attribute].empty?

    "#{record.model_name.param_key}_#{attribute}_error"
  end
end
