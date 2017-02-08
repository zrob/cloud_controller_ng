module VCAP::CloudController
  module Jobs
    class RecordCompletedJob < WrappingJob
      # TODO: could this be better implemented via hooks?
      # https://github.com/collectiveidea/delayed_job#hooks

      def initialize(handler, queue)
        super(handler)
        @queue = queue
      end

      def perform
        super
        # TODO: racey?
        record = LastSuccessfulJob.where(name: @queue).first
        if record.nil?
          LastSuccessfulJob.insert(name: @queue, last_completed_at: Time.now)
        else
          record.update(last_completed_at: Time.now)
        end
      end

      def job
        @handler
      end
    end
  end
end
