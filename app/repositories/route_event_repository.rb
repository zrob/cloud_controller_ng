module VCAP::CloudController
  module Repositories
    class RouteEventRepository
      attr_reader :user, :current_user_email

      def initialize(user:, user_email:)
        @user               = user
        @current_user_email = user_email
      end

      def record_route_create(route, request_attrs)
        Event.create(
          space:      route.space,
          type:       'audit.route.create',
          actee:      route.guid,
          actee_type: 'route',
          actee_name: route.host,
          actor:      @user.guid,
          actor_type: 'user',
          actor_name: @current_user_email,
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
          actor:      @user.guid,
          actor_type: 'user',
          actor_name: @current_user_email,
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
          actor:             @user.guid,
          actor_type:        'user',
          actor_name:        @current_user_email,
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
