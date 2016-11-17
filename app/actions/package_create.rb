require 'repositories/package_event_repository'

module VCAP::CloudController
  class PackageCreate
    class InvalidPackage < StandardError; end

    def initialize(user_info)
      @user_info = user_info
    end

    def create(message:, record_event: true)
      Steno.logger('cc.action.package_create').info("creating package type #{message.type} for app #{message.app_guid}")

      package              = PackageModel.new
      package.app_guid     = message.app_guid
      package.type         = message.type
      package.state        = get_package_state(message)
      package.docker_image = message.docker_data.image if message.docker_type?

      package.db.transaction do
        package.save
        record_audit_event(package, message) if record_event
      end

      package
    rescue Sequel::ValidationFailed => e
      raise InvalidPackage.new(e.message)
    end

    def create_without_event(message)
      create(message: message, record_event: false)
    end

    private

    def record_audit_event(package, message)
      Repositories::PackageEventRepository.new(@user_info).record_app_package_create(
        package,
        message.audit_hash)
    end

    def get_package_state(message)
      message.bits_type? ? PackageModel::CREATED_STATE : PackageModel::READY_STATE
    end
  end
end
