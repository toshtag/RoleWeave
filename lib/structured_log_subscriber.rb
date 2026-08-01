# 要求とジョブの完了を、1 行の JSON として出す。
#
# 既定のログは残す。development で読めなくなるのを避けるためである。
# 出す項目は StructuredLog が決める。
# 方針は docs/decisions/0048-structured-logging.md を正本とする。
module StructuredLogSubscriber
  def self.subscribe(logger:)
    ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)

      logger.info(StructuredLog.request(event.payload.merge(duration: event.duration)).to_json)
    end

    ActiveSupport::Notifications.subscribe("perform.active_job") do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)

      logger.info(StructuredLog.job(event.payload.merge(duration: event.duration), event: "job").to_json)
    end
  end
end
