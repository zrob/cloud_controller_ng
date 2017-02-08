require 'clockwork'

module VCAP::CloudController
  class Clock
    def initialize(config)
      @config = config
      @logger = Steno.logger('cc.clock')
    end

    def schedule_cleanup(name, klass, at)
      config = @config.fetch(name.to_sym)
      cutoff_age_in_days = config.fetch(:cutoff_age_in_days)

      schedule_simple_job(
        interval: 1.day,
        name: "#{name}.cleanup.job",
        clock_options: { at: at },
        job: klass.new(cutoff_age_in_days)
      )
    end

    def schedule_frequent_job(name, klass, queue: 'cc-generic', priority: nil)
      config = @config.fetch(name.to_sym)
      expiration = config[:expiration_in_seconds]
      schedule_simple_job(
        interval: config.fetch(:frequency_in_seconds),
        name: "#{name}.job",
        job: if expiration
               klass.new(expiration)
             else
               klass.new
             end,
        clock_options: {},
      )
    end

    def schedule_locking_job(name:, klass:, job_options:)
      config = @config.fetch(name.to_sym)
      interval = config.fetch(:frequency_in_seconds)
      expiration = config[:expiration_in_seconds]
      Clockwork.every(interval, "#{name}.cleanup.job") do |_|
        opts = job_options.dup # delayed_job will mutate the passed options causing errors...

        job = if expiration
                klass.new(expiration)
              else
                klass.new
              end

        VCAP::CloudController::Locking.db.transaction do
          VCAP::CloudController::Locking[name: 'clock'].lock!

          skip = false

          queue = opts[:queue]
          if queued_or_running_job?(queue)
            @logger.info("Skipping enqueue of #{name} as one is already running or queued")
            skip = true
          elsif has_ran_already_during_interval?(queue, interval)
            @logger.info("Skipping enqueue of #{name} as one has already ran in the interval")
            skip = true
          end

          unless skip
            @logger.info("Queueing #{job.class} into #{queue} at #{Time.now.utc}")
            # TODO: how to have clockwork log all errors
            begin
              Jobs::Enqueuer.new(job, opts).enqueue
            rescue Exception => e
              @logger.error("Clockwork error: #{e.inspect}")
            end
          end
        end
      end
    end

    def schedule_daily(name, klass, at)
      schedule_simple_job(
        interval: 1.day,
        name: "#{name}.cleanup.job",
        clock_options: { at: at },
        job: klass.new,
      )
    end

    private

    def schedule_simple_job(interval:, name:, clock_options:, job:)
      Clockwork.every(interval, "#{name}.cleanup.job", clock_options) do |_|
        @logger.info("Queueing #{job.class} at #{Time.now.utc}")
        Jobs::Enqueuer.new(job, queue: 'cc-generic').enqueue
      end
    end

    def queued_or_running_job?(queue)
      # TODO: do we retry failed jobs?
      # TODO: what if a worker is killed after acquiring lock, do we need to prune locks?
      # queue, failed_at, locked_at
      # sync, nil, nil <- queued
      # sync, nil, TIME <- running
      Delayed::Job.where(queue: queue, failed_at: nil).count > 0
    end

    def has_ran_already_during_interval?(queue, interval)
      # TODO: should we tick more often?
      # E.g. separate tick_interval and job_interval?
      job = LastSuccessfulJob.where(name: queue).first
      Time.now - interval < job.last_completed_at
    end
  end
end
