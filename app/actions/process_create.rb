require 'repositories/process_event_repository'

module VCAP::CloudController
  class ProcessCreate
    def initialize(user_info)
      @user_info = user_info
    end

    def create(app, message)
      attrs = message.merge({
        diego:             true,
        instances:         message[:type] == 'web' ? 1 : 0,
        health_check_type: message[:type] == 'web' ? 'port' : 'process',
        metadata:          {},
      })
      attrs[:guid] = app.guid if message[:type] == 'web'

      process = nil
      app.class.db.transaction do
        process = app.add_process(attrs)
        Repositories::ProcessEventRepository.new(@user_info).record_create(process)
      end

      process
    end
  end
end
