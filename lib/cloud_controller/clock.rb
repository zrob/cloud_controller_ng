require 'clockwork'

module VCAP::CloudController
  class Clock
    def initialize(config)
      @config = config
      @logger = Steno.logger('cc.clock')
    end

    def schedule_cleanup(name, klass, at)
      config = @config.fetch(name.to_sym)

      Clockwork.every(1.day, "#{name}.cleanup.job", at: at) do |_|
        @logger.info("Queueing #{klass} at #{Time.now.utc}")
        cutoff_age_in_days = config.fetch(:cutoff_age_in_days)
        job                = klass.new(cutoff_age_in_days)
        Jobs::Enqueuer.new(job, queue: 'cc-generic').enqueue
      end
    end

    def schedule_frequent_job(name, klass, queue: 'cc-generic', priority: nil, extra_options: {})
      config = @config.fetch(name.to_sym)

      Clockwork.every(config.fetch(:frequency_in_seconds), "#{name}.job", extra_options) do |_|
        @logger.info("Queueing #{klass} at #{Time.now.utc}")
        expiration = config[:expiration_in_seconds]
        job = if expiration
                klass.new(expiration)
              else
                klass.new
              end
        opts = { queue: queue }
        opts[:priority] = priority if priority
        Jobs::Enqueuer.new(job, opts).enqueue
      end
    end

    def schedule_daily(name, klass, at)
      Clockwork.every(1.day, "#{name}.cleanup.job", at: at) do |_|
        @logger.info("Queueing #{klass} at #{Time.now.utc}")
        Jobs::Enqueuer.new(klass.new, queue: 'cc-generic').enqueue
      end
    end
  end
end
