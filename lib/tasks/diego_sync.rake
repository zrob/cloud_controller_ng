namespace :diego_sync do
  desc "Start diego sync ???????"
  task :start do
    require "diego_sync/syncer"

    BackgroundJobEnvironment.new(RakeConfig.config).setup_environment
    syncer = DiegoSync::Syncer.new(RakeConfig.config)
    syncer.start
  end
end
