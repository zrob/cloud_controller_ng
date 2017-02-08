require 'cloud_controller/diego/processes_sync'
require 'cloud_controller/diego/tasks_sync'

module VCAP::CloudController
  module Jobs
    module Diego
      class Sync < VCAP::CloudController::Jobs::CCJob
        def perform
          config = CloudController::DependencyLocator.instance.config

          VCAP::CloudController::Diego::ProcessesSync.new(config).sync if config.fetch(:diego, {}).fetch(:temporary_local_apps, false)
          VCAP::CloudController::Diego::TasksSync.new.sync if config.fetch(:diego, {}).fetch(:temporary_local_tasks, false)
        end
      end
    end
  end
end
