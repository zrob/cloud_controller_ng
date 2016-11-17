require 'spec_helper'
require 'actions/package_upload'

module VCAP::CloudController
  RSpec.describe PackageUpload do
    subject(:package_upload) { PackageUpload.new(user_info) }
    let(:user_info) { VCAP::CloudController::Audit::UserInfo.new(guid: 'user_guid', email: 'user_email') }

    describe '#upload_async' do
      let(:package) { PackageModel.make(type: 'bits') }
      let(:message) { PackageUploadMessage.new({ 'bits_path' => '/tmp/path' }) }
      let(:config) { { name: 'local', index: '1' } }

      it 'enqueues and returns an upload job' do
        returned_job = nil
        expect {
          returned_job = package_upload.upload_async(message: message, package: package, config: config)
        }.to change { Delayed::Job.count }.by(1)

        job = Delayed::Job.last
        expect(returned_job).to eq(job)
        expect(job.queue).to eq('cc-local-1')
        expect(job.handler).to include(package.guid)
        expect(job.handler).to include('PackageBits')
      end

      it 'changes the state to pending' do
        package_upload.upload_async(message: message, package: package, config: config)
        expect(PackageModel.find(guid: package.guid).state).to eq(PackageModel::PENDING_STATE)
      end

      it 'creates an audit event' do
        package_upload.upload_async(message: message, package: package, config: config)

        event = Event.last
        expect(event.type).to eq('audit.app.package.upload')
        expect(event.metadata['package_guid']).to eq(package.guid)
      end

      context 'when the package is invalid' do
        before do
          allow(package).to receive(:save).and_raise(Sequel::ValidationFailed.new('message'))
        end

        it 'raises InvalidPackage' do
          expect {
            package_upload.upload_async(message: message, package: package, config: config)
          }.to raise_error(PackageUpload::InvalidPackage)
        end
      end
    end

    describe '#upload_async_without_event' do
      let(:package) { PackageModel.make(type: 'bits') }
      let(:message) { PackageUploadMessage.new({ 'bits_path' => '/tmp/path' }) }
      let(:config) { { name: 'local', index: '1' } }

      it 'enqueues and returns an upload job' do
        returned_job = nil
        expect {
          returned_job = package_upload.upload_async_without_event(message: message, package: package, config: config)
        }.to change { Delayed::Job.count }.by(1)

        job = Delayed::Job.last
        expect(returned_job).to eq(job)
        expect(job.queue).to eq('cc-local-1')
        expect(job.handler).to include(package.guid)
        expect(job.handler).to include('PackageBits')
      end

      it 'does not create an audit event' do
        expect_any_instance_of(Repositories::PackageEventRepository).not_to receive(:record_app_package_upload)
        package_upload.upload_async_without_event(message: message, package: package, config: config)
      end
    end

    describe '#upload_sync_without_event' do
      let(:package) { PackageModel.make(type: 'bits') }
      let(:message) { PackageUploadMessage.new({ 'bits_path' => '/tmp/path' }) }

      before do
        allow_any_instance_of(Jobs::V3::PackageBits).to receive(:perform).and_return(nil)
      end

      it 'performs the upload job' do
        expect_any_instance_of(Jobs::V3::PackageBits).to receive(:perform)
        package_upload.upload_sync_without_event(message, package)
      end

      context 'when the package is invalid' do
        before do
          allow_any_instance_of(Jobs::V3::PackageBits).to receive(:perform).and_raise(Sequel::ValidationFailed.new('message'))
        end

        it 'raises InvalidPackage' do
          expect {
            package_upload.upload_sync_without_event(message, package)
          }.to raise_error(PackageUpload::InvalidPackage)
        end
      end
    end
  end
end
