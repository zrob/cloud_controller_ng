module DiegoSync
  class Syncer
    def initialize(config)
      @config = config
    end

    def start
      VCAP::CloudController::DB.load_models(@config.fetch(:db), logger)

      loop do
        interval = HashUtils.dig(config, :diego_sync, :frequency_in_seconds)
        # TODO: should we crash if an error occurs in the loop?
        tick(interval)

        sleep interval
      end
    end

    def tick(interval)
      VCAP::CloudController::Locking.db.transaction do
        VCAP::CloudController::Locking[name: 'diego-sync'].lock!

        if has_ran_already_during_interval?(interval)
          logger.debug('Sync has already been run in interval, skipping...')
          break
        end

        VCAP::CloudController::Diego::ProcessesSync.new(config).sync
        VCAP::CloudController::Diego::TasksSync.new.sync

        record_completed_job
      end
    end

    private

    attr_reader :config

    def logger
      @logger ||= Steno.logger('cc.diego-sync')
    end

    def has_ran_already_during_interval?(interval)
      # TODO: should we tick more often?
      # E.g. separate tick_interval and job_interval?
      job = VCAP::CloudController::LastSuccessfulJob.where(name: 'diego-sync').first
      if job.nil?
        false
      else
        Time.now - interval < job.last_completed_at
      end
    end

    def record_completed_job
      record = VCAP::CloudController::LastSuccessfulJob.where(name: 'diego-sync').first
      if record.nil?
        VCAP::CloudController::LastSuccessfulJob.insert(name: 'diego-sync', last_completed_at: Time.now)
      else
        record.update(last_completed_at: Time.now)
      end
    end
  end
end
