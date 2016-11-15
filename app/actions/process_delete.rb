module VCAP::CloudController
  class ProcessDelete
    def initialize(user_info)
      @user_info = user_info
    end

    def delete(processes)
      processes = Array(processes)

      processes.each do |process|
        process.db.transaction do
          process.lock!
          Repositories::ProcessEventRepository.new(@user_info).record_delete(process)
          process.destroy
        end
      end
    end
  end
end
