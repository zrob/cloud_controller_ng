module VCAP::CloudController
  class AppCreate
    class InvalidApp < StandardError; end

    def initialize(user_info)
      @user_info = user_info
      @logger    = Steno.logger('cc.action.app_create')
    end

    def create(message, lifecycle)
      app = nil
      AppModel.db.transaction do
        app = AppModel.create(
          name:                  message.name,
          space_guid:            message.space_guid,
          environment_variables: message.environment_variables,
        )

        lifecycle.create_lifecycle_data_model(app)

        Repositories::AppEventRepository.new(@user_info).record_app_create(
          app,
          app.space,
          message.audit_hash
        )
      end

      app
    rescue Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
    end
  end
end
