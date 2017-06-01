module VCAP::CloudController
  class ACL
    FOUNDATION_ID = 'cf1'.freeze

    def self.load_from_file(acl_filepath)
      data = YAML.load_file(File.join(Rails.root, acl_filepath))
      new(data.deep_symbolize_keys)
    end

    attr_reader :data

    def initialize(data)
      @data = data || {}
    end

    def contains_rule?(resource_urn, action)
      return false unless FOUNDATION_ID == data.fetch(:foundation_id, nil)

      data.fetch(:statements, []).any? do |rule|
        rule[:resource] == resource_urn && rule[:action] == action
      end
    end
  end
end
