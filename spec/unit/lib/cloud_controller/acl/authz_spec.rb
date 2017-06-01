require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Authz do
    subject(:authz) { Authz.new(acl) }
    let(:acl) { ACL.new(acl_data) }
    let(:acl_data) do
      {
        foundation_id: 'cf1',
        statements: [
          { resource: "app:#{org_guid}/#{space_guid}/#{app_guid}", action: 'action1' },
          { resource: "app:#{org_guid}/#{space_guid}/*", action: 'action2' },
          { resource: "app:#{org_guid}/*", action: 'action3' },
          { resource: 'app:*', action: 'action4' },
        ]
      }
    end

    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:app_guid) { app_model.guid }
    let(:space_guid) { app_model.space.guid }
    let(:org_guid) { app_model.space.organization.guid }

    it 'can check for wildcard rule' do
      expect(authz.can_do?(app_model, 'action1')).to eq(true)
      expect(authz.can_do?(app_model, 'action2')).to eq(true)
      expect(authz.can_do?(app_model, 'action3')).to eq(true)
      expect(authz.can_do?(app_model, 'action4')).to eq(true)
    end
  end
end
