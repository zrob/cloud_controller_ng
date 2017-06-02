require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ACL do
    subject(:acl) do
      ACL.new({
        foundation_id: 'cf1',
        statements: acl_statements
      })
    end

    describe '#contains_rule?' do
      let(:acl_statements) do
        [
          { resource: 'app:random-path', action: 'task.list' },
          { resource: 'app:other-path/*', action: 'task.list' },
        ]
      end

      it 'can check for exact rule' do
        expect(acl.contains_rule?('app', 'random-path', 'task.list')).to eq(true)
        expect(acl.contains_rule?('app', 'random-path', 'task.delete')).to eq(false)
      end
    end

    describe '#get_rules' do
      # get_rules(resource_type, action)
      let(:acl_statements) do
        [
          { resource: 'app:random-path', action: 'action1' },
          { resource: 'app:random-path2', action: 'action1' },
          { resource: 'app:random-path3', action: 'action1' },

          { resource: 'app:random-path3', action: 'action2' },
          { resource: 'task:random-path3', action: 'action1' },
        ]
      end

      it 'returns urns matching resource_type and action' do
        expect(acl.get_rules(:app, 'action1')).to match_array([
          { resource: 'app:random-path', action: 'action1' },
          { resource: 'app:random-path2', action: 'action1' },
          { resource: 'app:random-path3', action: 'action1' }
        ])
      end
    end
  end
end
