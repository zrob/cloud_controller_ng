module VCAP::CloudController
  module Diego
    class StagingDetails
      attr_accessor :staging_guid, :memory_in_mb, :disk_in_mb, :package,
        :environment_variables, :lifecycle, :start_after_staging, :isolation_segment
    end
  end
end
