module VCAP::CloudController
  class ACL
    FOUNDATION_ID = 'cf1'.freeze

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

    def get_rules(resource_type, action)
      data.fetch(:statements, []).select do |rule|
        rule[:resource].split(':').first == resource_type.to_s && rule[:action] == action
      end
    end

  end
end
