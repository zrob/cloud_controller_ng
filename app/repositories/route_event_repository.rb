module VCAP::CloudController
  module Repositories
    class RouteEventRepository
      def initialize(user_info)
        @user_info = user_info
      end

      def self.from_security_context(security_context)
        new(VCAP::CloudController::Audit::UserInfo.from_security_context(security_context))
      end

      def record_route_create(route, request_attrs)
        Event.create(
          space:      route.space,
          type:       'audit.route.create',
          actee:      route.guid,
          actee_type: 'route',
          actee_name: route.host,
          actor:      @user_info.guid,
          actor_type: 'user',
          actor_name: @user_info.email,
          timestamp:  Sequel::CURRENT_TIMESTAMP,
          metadata:   {
            request: request_attrs
          }
        )
      end

      def record_route_update(route, request_attrs)
        Event.create(
          space:      route.space,
          type:       'audit.route.update',
          actee:      route.guid,
          actee_type: 'route',
          actee_name: route.host,
          actor:      @user_info.guid,
          actor_type: 'user',
          actor_name: @user_info.email,
          timestamp:  Sequel::CURRENT_TIMESTAMP,
          metadata:   {
            request: request_attrs
          }
        )
      end

      def record_route_delete_request(route, recursive)
        Event.create(
          type:              'audit.route.delete-request',
          actee:             route.guid,
          actee_type:        'route',
          actee_name:        route.host,
          actor:             @user_info.guid,
          actor_type:        'user',
          actor_name:        @user_info.email,
          timestamp:         Sequel::CURRENT_TIMESTAMP,
          space_guid:        route.space.guid,
          organization_guid: route.space.organization.guid,
          metadata:          {
            request: { recursive: recursive }
          }
        )
      end
    end
  end
end
