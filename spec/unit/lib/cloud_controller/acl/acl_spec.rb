require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ACL do
    subject(:acl) { ACL.new(acl_data) }

    describe '.load_from_file' do
      it 'can load form a config file' do
        acl_from_file = ACL.load_from_file('spec/fixtures/acls/test-acl.yml')
        expect(acl_from_file.data).to eq(
          {
            foundation_id: 'cf1',
            statements: [{
              action:   'task.list',
              resource: 'app:org-guid1/space-guid2/app-guid3',
            },
                         {
                           action:   'app.see_secrets',
                           resource: 'app:org-guid1/space-guid2/app-guid3',
                         }]
          }
        )
      end
    end

    describe '#contains_rule?' do
      let(:acl_data) do
        {
          foundation_id: 'cf1',
          statements: [
            { resource: 'app:random-path', action: 'task.list' },
            { resource: 'app:other-path/*', action: 'task.list' },
          ]
        }
      end

      it 'can check for exact rule' do
        expect(acl.contains_rule?('app', 'random-path', 'task.list')).to eq(true)
        expect(acl.contains_rule?('app', 'random-path', 'task.delete')).to eq(false)
      end
    end
  end
end
