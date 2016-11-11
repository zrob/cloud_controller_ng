require 'cloud_controller/diego/process_guid'

module VCAP::CloudController
  class AppsSSHController < RestController::ModelController
    NON_EXISTENT_CURRENT_USER = 'unknown-user-guid'.freeze
    NON_EXISTENT_CURRENT_USER_EMAIL = 'unknown-user-email'.freeze

    # Allow unauthenticated access so that we can take action if authentication
    # fails
    allow_unauthenticated_access only: [:ssh_access, :ssh_access_with_index]

    model_class_name :App

    get '/internal/apps/:guid/ssh_access/:index', :ssh_access_with_index
    def ssh_access_with_index(guid, index)
      index = index.nil? ? 'unknown' : index
      global_allow_ssh = VCAP::CloudController::Config.config[:allow_app_ssh_access]

      check_authentication(:ssh_access_internal)
      app = find_guid_and_validate_access(:update, guid)
      unless app.diego && app.enable_ssh && global_allow_ssh && app.space.allow_ssh
        raise ApiError.new_from_details('InvalidRequest')
      end

      record_ssh_authorized_event(app, index)

      response_body = { 'process_guid' => VCAP::CloudController::Diego::ProcessGuid.from_process(app) }
      [HTTP::OK, MultiJson.dump(response_body)]
    rescue => e
      app = App.find(guid: guid)
      record_ssh_unauthorized_event(app, index) unless app.nil?
      raise e
    end

    get '/internal/apps/:guid/ssh_access', :ssh_access
    def ssh_access(guid)
      ssh_access_with_index(guid, nil)
    end

    private

    def record_ssh_unauthorized_event(app, index)
      user_info = Audit::UserInfo.from_security_context(SecurityContext)
      user_info.guid  ||= NON_EXISTENT_CURRENT_USER
      user_info.email ||= NON_EXISTENT_CURRENT_USER_EMAIL

      Repositories::AppEventRepository.new(user_info).record_app_ssh_unauthorized(app, index)
    end

    def record_ssh_authorized_event(app, index)
      Repositories::AppEventRepository.new(audit_user_info).record_app_ssh_authorized(app, index)
    end
  end
end
