module VCAP::CloudController
  module Repositories
    class PackageEventRepository
      def initialize(user_info)
        @user_info = user_info
      end

      def record_app_package_create(package, request_attrs)
        app_guid = request_attrs.delete('app_guid')
        Loggregator.emit(app_guid, "Adding app package for app with guid #{app_guid}")

        metadata = {
          package_guid: package.guid,
          request:      request_attrs
        }
        type = 'audit.app.package.create'

        create_event(package, type, metadata)
      end

      def record_app_package_copy(package, source_package_guid)
        app = package.app
        Loggregator.emit(app.guid, "Adding app package for app with guid #{app.guid} copied from package with guid #{source_package_guid}")
        metadata = {
          package_guid: package.guid,
          request:      {
            source_package_guid: source_package_guid
          }
        }
        type = 'audit.app.package.create'

        create_event(package, type, metadata)
      end

      def record_app_package_upload(package)
        Loggregator.emit(package.app.guid, "Uploading app package for app with guid #{package.app.guid}")
        metadata = { package_guid: package.guid }
        type     = 'audit.app.package.upload'

        create_event(package, type, metadata)
      end

      def record_app_package_delete(package)
        Loggregator.emit(package.app.guid, "Deleting app package for app with guid #{package.app.guid}")
        metadata = { package_guid: package.guid }
        type     = 'audit.app.package.delete'

        create_event(package, type, metadata)
      end

      def record_app_package_download(package)
        Loggregator.emit(package.app.guid, "Downloading app package for app with guid #{package.app.guid}")
        metadata = { package_guid: package.guid }
        type     = 'audit.app.package.download'

        create_event(package, type, metadata)
      end

      def create_event(package, type, metadata)
        app = package.app
        Event.create(
          space:      package.space,
          type:       type,
          timestamp:  Sequel::CURRENT_TIMESTAMP,
          actee:      app.guid,
          actee_type: 'app',
          actee_name: app.name,
          actor:      @user_info.guid,
          actor_type: 'user',
          actor_name: @user_info.email,
          metadata:   metadata
        )
      end
    end
  end
end
