module VCAP::CloudController
  class ProcessTerminate
    class InstanceNotFound < StandardError; end

    def initialize(user_info, process, index)
      @user_info = user_info
      @process    = process
      @index      = index
    end

    def terminate
      raise InstanceNotFound unless @index < @process.instances && @index >= 0
      index_stopper.stop_index(@process, @index)
      record_audit_events
    end

    private

    def record_audit_events
      Repositories::ProcessEventRepository.new(@user_info).record_terminate(
        @process,
        @index
      )
    end

    def index_stopper
      CloudController::DependencyLocator.instance.index_stopper
    end
  end
end
