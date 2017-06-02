module VCAP::CloudController
  class Authz
    def initialize(acl)
      @acl = acl
    end

    def can_do?(resource, action)
      potential_urns = TranslateCCResourceToURNs.new.for_app(resource)
      potential_urns.any? { |urn| @acl.contains_rule?(urn, action) }
    end

    def get_app_filter_messages(resource_type, action)
      urns = @acl.get_rules(resource_type, action).map{ |rule| rule[:resource] }

      urns.map {|urn| TranslateURNtoCCResource.new.from_urn(urn) }
    end

    class TranslateURNtoCCResource
      class TaskFilterMessage < OpenStruct
        def requested?(key)
          self[key].present?
        end
      end

      def from_urn(urn)
        resource_type, path = urn.split(':', 2)
        return nil unless resource_type == 'app'

        org_guid, space_guid, app_guid = path.split('/')
        filter_message = TaskFilterMessage.new
        if app_guid && app_guid != '*'
          filter_message.app_guids = app_guid
        else
          if space_guid && space_guid != '*'
            filter_message.space_guids = space_guid
          else
            if org_guid != '*'
              filter_message.organization_guids = org_guid
            end
          end
        end
        filter_message
      end
    end

    class TranslateCCResourceToURNs
      def for_app(resource)
        [
          "app:#{resource.space.organization.guid}/#{resource.space.guid}/#{resource.guid}",
          "app:#{resource.space.organization.guid}/#{resource.space.guid}/*",
          "app:#{resource.space.organization.guid}/*",
          'app:*',
        ]
      end
    end
  end
end
