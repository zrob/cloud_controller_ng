require 'spec_helper'
require 'actions/droplet_copy'

module VCAP::CloudController
  RSpec.describe DropletCopy do
    subject(:droplet_copy) { DropletCopy.new(source_droplet, user_info) }

    let(:user_info) { VCAP::CloudController::Audit::UserInfo.new(guid: 'user_guid', email: 'user_email') }
    let(:source_space) { VCAP::CloudController::Space.make }

    let!(:target_app) { VCAP::CloudController::AppModel.make(name: 'target-app-name') }
    let!(:source_app) { VCAP::CloudController::AppModel.make(name: 'source-app-name', space: source_space) }
    let(:lifecycle_type) { :buildpack }
    let!(:source_droplet) do
      VCAP::CloudController::DropletModel.make(lifecycle_type,
        app_guid:              source_app.guid,
        droplet_hash:          'abcdef',
        process_types:         { web: 'bundle exec rails s' },
        environment_variables: { 'THING' => 'STUFF' },
        state:                 VCAP::CloudController::DropletModel::STAGED_STATE)
    end

    describe '#copy' do
      it 'copies the passed in droplet to the target app' do
        expect {
          droplet_copy.copy(target_app)
        }.to change { DropletModel.count }.by(1)

        copied_droplet = DropletModel.last

        expect(copied_droplet.state).to eq DropletModel::COPYING_STATE
        expect(copied_droplet.buildpack_receipt_buildpack_guid).to eq source_droplet.buildpack_receipt_buildpack_guid
        expect(copied_droplet.droplet_hash).to be nil
        expect(copied_droplet.environment_variables).to eq(nil)
        expect(copied_droplet.process_types).to eq({ 'web' => 'bundle exec rails s' })
        expect(copied_droplet.buildpack_receipt_buildpack).to eq source_droplet.buildpack_receipt_buildpack
        expect(copied_droplet.buildpack_receipt_stack_name).to eq source_droplet.buildpack_receipt_stack_name
        expect(copied_droplet.execution_metadata).to eq source_droplet.execution_metadata
        expect(copied_droplet.staging_memory_in_mb).to eq source_droplet.staging_memory_in_mb
        expect(copied_droplet.staging_disk_in_mb).to eq source_droplet.staging_disk_in_mb
        expect(copied_droplet.docker_receipt_image).to eq source_droplet.docker_receipt_image

        expect(target_app.droplets).to include(copied_droplet)
      end

      it 'creates an audit event' do
        droplet_copy.copy(target_app)

        event = Event.last
        expect(event.type).to eq('audit.app.droplet.create')
        expect(event.metadata['request']['source_droplet_guid']).to eq(source_droplet.guid)
      end

      context 'when the source droplet is not STAGED' do
        before do
          source_droplet.update(state: DropletModel::FAILED_STATE)
        end

        it 'raises' do
          expect {
            droplet_copy.copy(target_app)
          }.to raise_error(/source droplet is not staged/)
        end
      end

      context 'when lifecycle is buildpack' do
        it 'creates a buildpack_lifecycle_data record for the new droplet' do
          expect {
            droplet_copy.copy(target_app)
          }.to change { BuildpackLifecycleDataModel.count }.by(1)

          copied_droplet = DropletModel.last

          expect(copied_droplet.buildpack_lifecycle_data.stack).not_to be nil
          expect(copied_droplet.buildpack_lifecycle_data.stack).to eq(source_droplet.buildpack_lifecycle_data.stack)
        end

        it 'enqueues a job to copy the droplet bits' do
          copied_droplet = nil

          expect {
            copied_droplet = droplet_copy.copy(target_app)
          }.to change { Delayed::Job.count }.by(1)

          job = Delayed::Job.last
          expect(job.queue).to eq('cc-generic')
          expect(job.handler).to include(copied_droplet.guid)
          expect(job.handler).to include(source_droplet.guid)
          expect(job.handler).to include('DropletBitsCopier')
        end
      end

      context 'when lifecycle is docker' do
        let(:lifecycle_type) { :docker }

        before do
          source_droplet.update(docker_receipt_image: 'urvashi/reddy')
        end

        it 'copies a docker droplet' do
          expect {
            droplet_copy.copy(target_app)
          }.to change { DropletModel.count }.by(1)

          copied_droplet = DropletModel.last

          expect(copied_droplet).to be_docker
          expect(copied_droplet.guid).to_not eq(source_droplet.guid)
          expect(copied_droplet.docker_receipt_image).to eq('urvashi/reddy')
          expect(copied_droplet.state).to eq(VCAP::CloudController::DropletModel::STAGED_STATE)
        end
      end
    end
  end
end
