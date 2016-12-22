require 'benchmark'

module VCAP::CloudController
  module Diego
    class Sync
      BATCH_SIZE = 500

      def initialize(config:)
        @config = config
        @workpool = Throttler.new(50)
        @outer_workpool = Throttler.new(10)
      end

      class Throttler
        STOP_WORKING = :stop

        def initialize(size)
          @size = size
          @works = Queue.new

          work
        end

        def submit(*args, &block)
          @works << [block, args]
        end

        def work
          @threads = []

          @size.times do
            @threads << Thread.new { consume_work }
          end
        end

        def drain
          @size.times do
            @works << STOP_WORKING
          end
          @threads.each(&:join)
        end

        private

        def consume_work
          loop do
            w = @works.pop
            return if w == STOP_WORKING

            w[0].call(*w[1])
          end
        rescue => e
          logger.info('error-consume-work', exception: e.inspect, backtrace: e.backtrace)
        end
      end

      def sync_processes
        logger.info('fetching-scheduling-infos.starting')
        lrps_hash = bbs_apps_client.fetch_scheduling_infos.index_by { |d| d.desired_lrp_key.process_guid }
        logger.info('fetching-scheduling-infos.done')

        logger.info('diffing.starting')
        logger.info('batched-actions.starting')
        diffs = diff(lrps_hash)
        logger.info('diffing.done')


        diffs[:missing].each_slice(BATCH_SIZE) do |missing_batch|
          guids = missing_batch
          @outer_workpool.submit do
            processes = diego_processes_from_process_guids(guids)
            processes.each do |process|
              @workpool.submit do
                recipe_builder = AppRecipeBuilder.new(config: @config, process: process, default_health_check_timeout: @config[:default_health_check_timeout])

                desired_lrp = recipe_builder.build_app_lrp
                bbs_apps_client.desire_app(desired_lrp)
              end
            end
          end
        end

        diffs[:stale].each_slice(BATCH_SIZE) do |stale_batch|
          processes = diego_processes_from_process_guids(stale_batch)
          processes.each do |process|
            @workpool.submit do
              desire_message = protocol.desire_app_message(process, @config[:default_health_check_timeout])
              recipe_builder = AppRecipeBuilder.new(config: @config, process: process, app_request: desire_message)
              process_guid = Diego::ProcessGuid.from_process(process)

              existing_lrp = lrps_hash[process_guid]
              update_lrp = recipe_builder.build_app_lrp_update(existing_lrp)
              bbs_apps_client.update_app(process_guid, update_lrp)
            end
          end
        end

        diffs[:deleted].each do |process_guid|
          @workpool.submit do
            bbs_apps_client.stop_app(process_guid)
          end
        end

        @outer_workpool.drain
        @workpool.drain
        logger.info('batched-actions.done')

        logger.info('bumping-freshness.starting')
        bbs_apps_client.bump_freshness!
        logger.info('bumping-freshness.done')
      rescue => e
        logger.info('error', exception: e.inspect, backtrace: e.backtrace)
      end

      def protocol
        @protocol ||= Protocol.new
      end

      def bbs_apps_client
        CloudController::DependencyLocator.instance.bbs_apps_client
      end

      # def sync_tasks
      #   tasks = fetch_tasks_from_diego
      #   states = fetch_task_states_from_db

      #   to_fail, to_cancel = diff_task_states(tasks, states)

      #   fail_tasks(to_fail)
      #   cancel_tasks(to_cancel)

      #   bump_freshness! TASKS_DOMAIN
      # end

      def diff(lrps_hash)
        lrps_hash = lrps_hash.deep_dup
        missing = []
        stale = []

        for_app_fingerprints do |fingerprint|
          lrp = lrps_hash.delete(fingerprint[:process_guid])
          if lrp.nil?
            logger.info('found-missing-desired-lrp', process_guid: fingerprint[:process_guid], etag: fingerprint[:etag])
            missing << fingerprint[:process_guid]
            if missing.length == BATCH_SIZE
              @outer_workpool.submit(missing.pop(BATCH_SIZE)) do |guids|
                processes = diego_processes_from_process_guids(guids)
                processes.each do |process|
                  @workpool.submit(process) do |process|
                    recipe_builder = AppRecipeBuilder.new(config: @config, process: process, default_health_check_timeout: @config[:default_health_check_timeout])

                    desired_lrp = recipe_builder.build_app_lrp
                    bbs_apps_client.desire_app(desired_lrp)
                  end
                end
              end
            end
            next
          end

          if lrp.annotation != fingerprint[:etag]
            logger.info('found-stale-desired-lrp', process_guid: fingerprint[:process_guid], etag: fingerprint[:etag])
            stale << fingerprint[:process_guid]
          end
        end

        deleted = lrps_hash.keys

        { missing: missing, stale: stale, deleted: deleted }
      end

      def handle_diego_errors
        begin
          response = yield
        rescue ::Diego::Error => e
          raise CloudController::Errors::ApiError.new_from_details('RunnerUnavailable', e)
        end

        if response.error
          raise CloudController::Errors::ApiError.new_from_details('RunnerError', response.error.message)
        end

        response
      end

      def for_app_fingerprints(&block)
        last_id = 0

        loop do
          processes = diego_processes_cache_data(last_id)
          processes.each do |_id, guid, version, updated|
            block.call(
              process_guid: Diego::ProcessGuid.from(guid, version),
              etag: updated.to_f.to_s,
            )
          end
          return if processes.count < BATCH_SIZE
          last_id = processes.last[0]
        end
      end

      def diego_processes_cache_data(last_id)
        diego_processes = App.
          diego.
          runnable.
          where("#{App.table_name}.id > ?", last_id).
          order("#{App.table_name}__id".to_sym).
          limit(BATCH_SIZE)

        diego_processes = diego_processes.buildpack_type unless FeatureFlag.enabled?(:diego_docker)

        diego_processes.select_map([
          "#{App.table_name}__id".to_sym,
          "#{App.table_name}__guid".to_sym,
          "#{App.table_name}__version".to_sym,
          "#{App.table_name}__updated_at".to_sym
        ])
      end

    def diego_processes_from_process_guids(process_guids)
      process_guids = Array(process_guids).to_set
      App.select_all(App.table_name).
        diego.
        runnable.
        where("#{App.table_name}__guid".to_sym => process_guids.map { |pg| Diego::ProcessGuid.app_guid(pg) }).
        order("#{App.table_name}__id".to_sym).
        eager(:current_droplet, :space, :service_bindings, { routes: :domain }, { app: :buildpack_lifecycle_data }).
        all.
        select { |app| process_guids.include?(Diego::ProcessGuid.from_process(app)) }
    end

      def logger
        @logger ||= Steno.logger('cc.diego.sync')
      end
    end
  end
end
