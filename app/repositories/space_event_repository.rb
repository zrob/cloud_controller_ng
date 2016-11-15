module VCAP::CloudController
  module Repositories
    class SpaceEventRepository
      def initialize(user_info)
        @user_info = user_info
      end

      def self.from_security_context(security_context)
        new(VCAP::CloudController::Audit::UserInfo.from_security_context(security_context))
      end

      def record_space_create(space, request_attrs)
        Event.create(
          space:      space,
          type:       'audit.space.create',
          actee:      space.guid,
          actee_type: 'space',
          actee_name: space.name,
          actor:      @user_info.guid,
          actor_type: 'user',
          actor_name: @user_info.email,
          timestamp:  Sequel::CURRENT_TIMESTAMP,
          metadata:   {
            request: request_attrs
          }
        )
      end

      def record_space_update(space, request_attrs)
        Event.create(
          space:      space,
          type:       'audit.space.update',
          actee:      space.guid,
          actee_type: 'space',
          actee_name: space.name,
          actor:      @user_info.guid,
          actor_type: 'user',
          actor_name: @user_info.email,
          timestamp:  Sequel::CURRENT_TIMESTAMP,
          metadata:   {
            request: request_attrs
          }
        )
      end

      def record_space_delete_request(space, recursive)
        Event.create(
          type:              'audit.space.delete-request',
          actee:             space.guid,
          actee_type:        'space',
          actee_name:        space.name,
          actor:             @user_info.guid,
          actor_type:        'user',
          actor_name:        @user_info.email,
          timestamp:         Sequel::CURRENT_TIMESTAMP,
          space_guid:        space.guid,
          organization_guid: space.organization.guid,
          metadata:          {
            request: { recursive: recursive }
          }
        )
      end
    end
  end
end
