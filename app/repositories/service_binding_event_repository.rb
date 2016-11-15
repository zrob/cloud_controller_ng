module VCAP::CloudController
  module Repositories
    class ServiceBindingEventRepository
      def initialize(user_info)
        @user_info = user_info
      end

      def record_create(service_binding, request)
        attrs         = request.dup.stringify_keys
        attrs['data'] = 'PRIVATE DATA HIDDEN' if attrs.key?('data')

        record_event(
          type:            'audit.service_binding.create',
          service_binding: service_binding,
          metadata:        { request: attrs }
        )
      end

      def record_delete(service_binding)
        record_event(
          type:            'audit.service_binding.delete',
          service_binding: service_binding
        )
      end

      private

      def record_event(type:, service_binding:, metadata: {})
        Event.create(
          type:              type,
          actor:             @user_info.guid,
          actor_type:        'user',
          actor_name:        @user_info.email,
          actee:             service_binding.guid,
          actee_type:        'service_binding',
          actee_name:        '',
          space_guid:        service_binding.space.guid,
          organization_guid: service_binding.space.organization.guid,
          timestamp:         Sequel::CURRENT_TIMESTAMP,
          metadata:          metadata
        )
      end
    end
  end
end
