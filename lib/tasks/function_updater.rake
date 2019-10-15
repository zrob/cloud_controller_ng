namespace :function_updater do
  desc 'Start a recurring process to perform function syncs'
  task :start do
    require 'cloud_controller/function_updater/scheduler'

    RakeConfig.context = :api
    BackgroundJobEnvironment.new(RakeConfig.config).setup_environment
    VCAP::CloudController::FunctionUpdater::Scheduler.start
  end
end
