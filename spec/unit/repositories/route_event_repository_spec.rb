require 'spec_helper'

module VCAP::CloudController
  module Repositories
    RSpec.describe RouteEventRepository do
      subject(:route_event_repository) { RouteEventRepository.new(user_info) }

      let(:user_info) { Audit::UserInfo.new(guid: 'user-guid', email: user_email) }
      let(:route) { Route.make }
      let(:request_attrs) { { 'host' => 'dora', 'domain_guid' => route.domain.guid, 'space_guid' => route.space.guid } }
      let(:user_email) { 'some@email.com' }

      describe '#record_route_create' do
        it 'records event correctly' do
          event = route_event_repository.record_route_create(route, request_attrs)
          event.reload
          expect(event.space).to eq(route.space)
          expect(event.type).to eq('audit.route.create')
          expect(event.actee).to eq(route.guid)
          expect(event.actee_type).to eq('route')
          expect(event.actee_name).to eq(route.host)
          expect(event.actor).to eq('user-guid')
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.metadata).to eq({ 'request' => request_attrs })
        end

        context 'when the user email is unknown' do
          let(:user_email) { nil }

          it 'leaves actor name empty' do
            event = route_event_repository.record_route_create(route, request_attrs)
            event.reload
            expect(event.actor_name).to eq(nil)
          end
        end
      end

      describe '#record_route_update' do
        it 'records event correctly' do
          event = route_event_repository.record_route_update(route, request_attrs)
          event.reload
          expect(event.space).to eq(route.space)
          expect(event.type).to eq('audit.route.update')
          expect(event.actee).to eq(route.guid)
          expect(event.actee_type).to eq('route')
          expect(event.actee_name).to eq(route.host)
          expect(event.actor).to eq('user-guid')
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.metadata).to eq({ 'request' => request_attrs })
        end
      end

      describe '#record_route_delete' do
        let(:recursive) { true }

        before do
          route.destroy
        end

        it 'records event correctly' do
          event = route_event_repository.record_route_delete_request(route, recursive)
          event.reload
          expect(event.space).to eq(route.space)
          expect(event.type).to eq('audit.route.delete-request')
          expect(event.actee).to eq(route.guid)
          expect(event.actee_type).to eq('route')
          expect(event.actee_name).to eq(route.host)
          expect(event.actor).to eq('user-guid')
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.metadata).to eq({ 'request' => { 'recursive' => true } })
        end
      end
    end
  end
end
