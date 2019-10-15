require 'messages/base_message'

module VCAP::CloudController
  class FunctionCreateMessage < BaseMessage
    register_allowed_keys [:name, :artifact, :image, :git_repo, :git_revision, :relationships]

    validates_with NoAdditionalKeysValidator, RelationshipValidator

    validates :name, presence: true, length: { maximum: 250 }
    validates :artifact, presence: true, length: { maximum: 999 }
    validates :image, presence: true, length: { maximum: 999 }
    validates :git_repo, presence: true, length: { maximum: 999 }

    delegate :app_guid, to: :relationships_message

    def relationships_message
      @relationships_message ||= Relationships.new(relationships.deep_symbolize_keys)
    end

    class Relationships < BaseMessage
      register_allowed_keys [:app]

      validates_with NoAdditionalKeysValidator

      validates :app, presence: true, allow_nil: false, to_one_relationship: true

      def app_guid
        HashUtils.dig(app, :data, :guid)
      end
    end
  end
end
