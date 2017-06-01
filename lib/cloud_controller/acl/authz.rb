module VCAP::CloudController
  class Authz
    def initialize(acl)
      @acl = acl
    end

    def can_do?(resource, action)
      potential_urns = TranslateCCResourceToURNs.new.for_app(resource)
      potential_urns.any? do |urn|
        @acl.contains_rule?(urn, action)
      end
    end

    class TranslateCCResourceToURNs
      def for_app(resource)
        [
          "app:#{resource.space.organization.guid}/#{resource.space.guid}/#{resource.name}",
          "app:#{resource.space.organization.guid}/#{resource.space.guid}/*",
          "app:#{resource.space.organization.guid}/*",
          'app:*',
        ]
      end
    end
  end
end
