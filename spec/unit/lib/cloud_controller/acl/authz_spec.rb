require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Authz do
    subject(:authz) { Authz.new(acl) }
    let(:acl) { ACL.new(acl_data) }
    let(:acl_data) do
      {
        foundation_id: 'cf1',
        statements: acl_statements,
      }
    end

    describe '#can_do?' do
      let(:app_model) { VCAP::CloudController::AppModel.make }
      let(:app_guid) { app_model.guid }
      let(:space_guid) { app_model.space.guid }
      let(:org_guid) { app_model.space.organization.guid }

      let(:acl_statements) do
        [
          { resource: "app:#{org_guid}/#{space_guid}/#{app_guid}", action: 'action1' },
          { resource: "app:#{org_guid}/#{space_guid}/*", action: 'action2' },
          { resource: "app:#{org_guid}/*", action: 'action3' },
          { resource: 'app:*', action: 'action4' },
        ]
      end

      it 'can check for wildcard rule' do
        expect(authz.can_do?(app_model, 'action1')).to eq(true)
        expect(authz.can_do?(app_model, 'action2')).to eq(true)
        expect(authz.can_do?(app_model, 'action3')).to eq(true)
        expect(authz.can_do?(app_model, 'action4')).to eq(true)
      end
    end

    describe '#get_app_filter_messages' do
      let!(:org1) { VCAP::CloudController::Organization.make }
      let!(:space1) { VCAP::CloudController::Space.make(organization: org1) }
      let!(:app1) { VCAP::CloudController::AppModel.make(space: space1) }
      let!(:app2) { VCAP::CloudController::AppModel.make(space: space1) }

      let!(:space2) { VCAP::CloudController::Space.make(organization: org1) }
      let!(:app3) { VCAP::CloudController::AppModel.make(space: space2) }

      let!(:org2) { VCAP::CloudController::Organization.make }
      let!(:space3) { VCAP::CloudController::Space.make(organization: org2) }
      let!(:app4) { VCAP::CloudController::AppModel.make(space: space3) }

      context 'when fetching all apps' do
        let(:acl_statements) do
          [
            { resource: 'app:*', action: 'action1' },
          ]
        end

        it 'fetches the right app models' do
          expect(authz.get_app_filter_messages(:app, 'action1')).to match_array([
            Authz::TranslateURNtoCCResource::TaskFilterMessage.new
          ])
        end
      end

      context 'when fetching all apps in an org' do
        let(:acl_statements) do
          [
            { resource: "app:#{org1.guid}/*", action: 'action1' },
            { resource: "app:#{org2.guid}/*", action: 'action2' },
          ]
        end

        it 'fetches the right app models' do
          expect(authz.get_app_filter_messages(:app, 'action1')).to match_array([
            Authz::TranslateURNtoCCResource::TaskFilterMessage.new(organization_guids: org1.guid)
          ])
        end
      end

      context 'when fetching all apps in a space' do
        let(:acl_statements) do
          [
            { resource: "app:#{org1.guid}/#{space1.guid}/*", action: 'action1' },
            { resource: "app:#{org1.guid}/#{space2.guid}/*", action: 'action2' },
          ]
        end

        it 'fetches the right app models' do
          expect(authz.get_app_filter_messages(:app, 'action1')).to match_array([
            Authz::TranslateURNtoCCResource::TaskFilterMessage.new(
              organization_guids: org1.guid,
              space_guids: space1.guid,
            )
          ])
        end
      end

      context 'when fetching a specific app' do
        let(:acl_statements) do
          [
            { resource: "app:#{org1.guid}/#{space1.guid}/#{app1.guid}", action: 'action1' },
            { resource: "app:#{org1.guid}/#{space1.guid}/#{app2.guid}", action: 'action2' },
          ]
        end

        it 'fetches the right app models' do
          expect(authz.get_app_filter_messages(:app, 'action1')).to match_array([
            Authz::TranslateURNtoCCResource::TaskFilterMessage.new(
              organization_guids: org1.guid,
              space_guids: space1.guid,
              guids: app1.guid,
            )
          ])
        end
      end

      context 'when given overlapping ACEs' do
        let(:acl_statements) do
          [
            { resource: 'app:*', action: 'action1' },
            { resource: "app:#{org1.guid}/*", action: 'action1' },
          ]
        end

        it 'generates the correct AppFilterMessages' do
          expect(authz.get_app_filter_messages(:app, 'action1')).to match_array([
            Authz::TranslateURNtoCCResource::TaskFilterMessage.new,
            Authz::TranslateURNtoCCResource::TaskFilterMessage.new(organization_guids: org1.guid),
          ])
        end
      end
    end
  end
end
