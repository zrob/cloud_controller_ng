require 'clockwork'
require 'cloud_controller/clock/clock'
require 'cloud_controller/clock/job_timeout_calculator'

module VCAP::CloudController
  class Scheduler
    CLEANUPS = [
      { name: 'app_usage_events', class: Jobs::Runtime::AppUsageEventsCleanup, time: '18:00', cutoff: true },
      { name: 'audit_events', class: Jobs::Runtime::EventsCleanup, time: '20:00', cutoff: true },
      { name: 'failed_jobs', class: Jobs::Runtime::FailedJobsCleanup, time: '21:00', cutoff: true },
      { name: 'service_usage_events', class: Jobs::Services::ServiceUsageEventsCleanup, time: '22:00', cutoff: true },
      { name: 'completed_tasks', class: Jobs::Runtime::PruneCompletedTasks, time: '23:00', cutoff: true },
      { name: 'expired_blob_cleanup', class: Jobs::Runtime::ExpiredBlobCleanup, time: '00:00', cutoff: false },
      { name: 'expired_resource_cleanup', class: Jobs::Runtime::ExpiredResourceCleanup, time: '00:30', cutoff: false },
      { name: 'expired_orphaned_blob_cleanup', class: Jobs::Runtime::ExpiredOrphanedBlobCleanup, time: '01:00', cutoff: false },
      { name: 'orphaned_blobs_cleanup', class: Jobs::Runtime::OrphanedBlobsCleanup, time: '01:30', priority: Clock::MEDIUM_PRIORITY, cutoff: false },
      { name: 'pollable_job_cleanup', class: Jobs::Runtime::PollableJobCleanup, time: '02:00', cutoff: false },
    ].freeze

    FREQUENTS = [
      { name: 'pending_droplets', class: Jobs::Runtime::PendingDropletCleanup },
      { name: 'pending_builds', class: Jobs::Runtime::PendingBuildCleanup },
    ].freeze

    def initialize(config)
      @clock = Clock.new
      @config = config
      @logger = Steno.logger('cc.clock')
      @timeout_calculator = JobTimeoutCalculator.new(@config)
    end

    def start
      start_daily_jobs
      start_frequent_jobs
      start_inline_jobs

      Clockwork.error_handler { |error| @logger.error("#{error} (#{error.class.name})") }
      Clockwork.run
    end

    private

    def start_inline_jobs
      clock_opts = {
        name: 'diego_sync',
        interval: @config.get(:diego_sync, :frequency_in_seconds),
        timeout: @timeout_calculator.calculate(:diego_sync),
      }
      @clock.schedule_frequent_inline_job(clock_opts) do
        Jobs::Diego::Sync.new
      end

      @clock.schedule_frequent_inline_job({name: 'deployer', interval: 2, timeout: 1000}) do
        Deploy.new
      end
    end

    def start_frequent_jobs
      FREQUENTS.each do |job_config|
        clock_opts = {
          name: job_config[:name],
          interval: @config.get(job_config[:name].to_sym, :frequency_in_seconds),
        }
        @clock.schedule_frequent_worker_job(clock_opts) do
          klass = job_config[:class]
          klass.new(@config.get(job_config[:name].to_sym, :expiration_in_seconds))
        end
      end
    end

    def start_daily_jobs
      CLEANUPS.each do |cleanup_config|
        clock_opts = {
          name: cleanup_config[:name],
          at: cleanup_config[:time],
          priority: cleanup_config[:priority] ? cleanup_config[:priority] : Clock::HIGH_PRIORITY
        }

        @clock.schedule_daily_job(clock_opts) do
          klass = cleanup_config[:class]
          if cleanup_config[:cutoff]
            cutoff_age_in_days = @config.get(cleanup_config[:name].to_sym, :cutoff_age_in_days)
            klass.new(cutoff_age_in_days)
          else
            klass.new
          end
        end
      end
    end
  end
end
