require 'spec_helper'
require 'repositories/droplet_event_repository'

module VCAP::CloudController
  module Repositories
    RSpec.describe DropletEventRepository do
      subject(:repository) { DropletEventRepository.new(user_info) }
      let(:user_info) { VCAP::CloudController::Audit::UserInfo.new(guid: 'user_guid', email: 'user_email') }
      let(:app) { AppModel.make(name: 'popsicle') }
      let(:package) { PackageModel.make(app_guid: app.guid) }
      let(:droplet) { DropletModel.make(app_guid: app.guid, package: package) }

      describe '#record_create_by_staging' do
        let(:request_attrs) do
          {
            'environment_variables' => {
              'foo' => 'bar'
            },
            'app_guid' => 'app-guid',
            'type'     => 'docker',
            'url'      => 'dockerurl.example.com'
          }
        end

        it 'creates a new audit.app.droplet.create event' do
          event = repository.record_create_by_staging(droplet, request_attrs, app.name, package.space.guid, package.space.organization.guid)
          event.reload

          expect(event.type).to eq('audit.app.droplet.create')
          expect(event.actor).to eq('user_guid')
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq('user_email')
          expect(event.actee).to eq(droplet.app_guid)
          expect(event.actee_type).to eq('app')
          expect(event.actee_name).to eq('popsicle')
          expect(event.space_guid).to eq(app.space.guid)

          metadata = event.metadata
          expect(metadata['droplet_guid']).to eq(droplet.guid)
          expect(metadata['package_guid']).to eq(package.guid)

          request = event.metadata['request']
          expect(request['app_guid']).to eq('app-guid')
          expect(request['type']).to eq('docker')
          expect(request['url']).to eq('dockerurl.example.com')
          expect(request['environment_variables']).to eq('PRIVATE DATA HIDDEN')
        end
      end

      describe '#record_create_by_copying' do
        let(:source_droplet_guid) { 'source-droplet-guid' }

        it 'creates a new audit.app.droplet.create event' do
          event = repository.record_create_by_copying(droplet.guid,
                                                                  source_droplet_guid,
                                                                  app.guid,
                                                                  app.name,
                                                                  package.space.guid,
                                                                  package.space.organization.guid
                                                                 )
          event.reload

          expect(event.type).to eq('audit.app.droplet.create')
          expect(event.actor).to eq('user_guid')
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq('user_email')
          expect(event.actee).to eq(droplet.app_guid)
          expect(event.actee_type).to eq('app')
          expect(event.actee_name).to eq('popsicle')
          expect(event.space_guid).to eq(app.space.guid)

          metadata = event.metadata
          expect(metadata['droplet_guid']).to eq(droplet.guid)
          expect(metadata['request']).to eq({ 'source_droplet_guid' => source_droplet_guid })
        end
      end

      describe '#record_delete' do
        it 'creates a new audit.app.droplet.delete event' do
          event = repository.record_delete(droplet, app.name, package.space.guid, package.space.organization.guid)
          event.reload

          expect(event.type).to eq('audit.app.droplet.delete')
          expect(event.actor).to eq('user_guid')
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq('user_email')
          expect(event.actee).to eq(droplet.app_guid)
          expect(event.actee_type).to eq('app')
          expect(event.actee_name).to eq('popsicle')
          expect(event.space_guid).to eq(app.space.guid)
          expect(event.metadata['droplet_guid']).to eq(droplet.guid)
        end
      end

      describe '#record_download' do
        it 'creates a new audit.app.droplet.download event' do
          event = repository.record_download(droplet, app.name, package.space.guid, package.space.organization.guid)
          event.reload

          expect(event.type).to eq('audit.app.droplet.download')
          expect(event.actor).to eq('user_guid')
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq('user_email')
          expect(event.actee).to eq(droplet.app_guid)
          expect(event.actee_type).to eq('app')
          expect(event.actee_name).to eq('popsicle')
          expect(event.space_guid).to eq(app.space.guid)
          expect(event.metadata['droplet_guid']).to eq(droplet.guid)
        end
      end
    end
  end
end
