require 'cloud_controller/function_updater/updater'
require 'locket/lock_worker'
require 'locket/lock_runner'

module VCAP::CloudController
  module FunctionUpdater
    class Scheduler
      class << self
        def start
          loop do
            update(update_frequency: 3)
          end
        end

        private

        def update(update_frequency:)
          logger = Steno.logger('cc.function_updater.scheduler')

          u = Updater.new

          update_start_time = Time.now
          u.syncify
          update_duration = Time.now - update_start_time
          logger.info("Update loop took #{update_duration}s")

          sleep_duration = update_frequency - update_duration
          if sleep_duration > 0
            logger.info("Sleeping #{sleep_duration}s")
            sleep(sleep_duration)
          else
            logger.info('Not Sleeping')
          end
        end

        def with_error_logging(error_message)
          yield
        rescue => e
          logger = Steno.logger('cc.function_updater')
          error_name = e.is_a?(CloudController::Errors::ApiError) ? e.name : e.class.name
          logger.error(
            error_message,
            error: error_name,
            error_message: e.message,
            backtrace: e.backtrace.join("\n"),
          )
        end
      end
    end
  end
end
