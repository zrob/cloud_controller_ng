require 'spec_helper'
require 'actions/process_terminate'

module VCAP::CloudController
  RSpec.describe ProcessTerminate do
    subject(:process_terminate) { ProcessTerminate.new(user_info, process, index) }
    let(:user_info) { VCAP::CloudController::Audit::UserInfo.new(guid: 'user-guid', email: 'user_email') }
    let(:app) { AppModel.make }
    let!(:process) { AppFactory.make(app: app) }
    let(:index) { 0 }

    let(:index_stopper) { double(IndexStopper, stop_index: true) }

    before do
      allow(CloudController::DependencyLocator.instance).to receive(:index_stopper).and_return(index_stopper)
    end

    describe '#terminate' do
      it 'terminates the process instance' do
        expect(process.instances).to eq(1)
        process_terminate.terminate
        expect(index_stopper).to have_received(:stop_index).with(process, 0)
      end

      it 'creates an audit event' do
        process_terminate.terminate

        event = Event.last
        expect(event.type).to eq('audit.app.process.terminate_instance')
        expect(event.metadata['process_guid']).to eq(process.guid)
        expect(event.metadata['process_index']).to eq(index)
      end

      context 'when index is greater than the number of process instances' do
        let(:index) { 6 }

        it 'raises InstanceNotFound' do
          expect {
            process_terminate.terminate
          }.to raise_error(ProcessTerminate::InstanceNotFound)
        end
      end
    end
  end
end
