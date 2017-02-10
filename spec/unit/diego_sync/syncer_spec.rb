require 'spec_helper'
require 'diego_sync/syncer'

module DiegoSync
  RSpec.describe Syncer do
    subject(:syncer) { Syncer.new(config) }
    let(:config) { { diego_sync: { frequency_in_seconds: frequency_in_seconds } } }
    let(:frequency_in_seconds) { 30 }

    let(:processes_sync) { instance_double(VCAP::CloudController::Diego::ProcessesSync, sync: nil) }
    let(:tasks_sync) { instance_double(VCAP::CloudController::Diego::ProcessesSync, sync: nil) }

    before do
      allow(VCAP::CloudController::Diego::ProcessesSync).to receive(:new).with(config).and_return(processes_sync)
      allow(VCAP::CloudController::Diego::TasksSync).to receive(:new).and_return(tasks_sync)
    end

    describe '#tick' do
      it 'syncs processes' do
        syncer.tick
        expect(processes_sync).to have_received(:sync).once
      end

      it 'syncs tasks' do
        syncer.tick
        expect(tasks_sync).to have_received(:sync).once
      end

      it 'runs at most once in parallel' do
        allow(tasks_sync).to receive(:sync) { sleep 2 }

        threads = [
          Thread.new { syncer.tick },
          Thread.new { syncer.tick },
        ]
        threads.each { |t| t.join(0.5) }
        threads.each(&:kill)

        expect(processes_sync).to have_received(:sync).once
        expect(tasks_sync).to have_received(:sync).once
      end
    end
  end
end
