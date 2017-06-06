module VCAP::CloudController
  class HistoricalJobModel < Sequel::Model(:historical_jobs)
    PROCESSING_STATE = 'PROCESSING'.freeze
    COMPLETE_STATE = 'COMPLETE'.freeze
    FAILED_STATE = 'FAILED'.freeze
  end
end
