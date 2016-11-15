require 'repositories/task_event_repository'

module VCAP::CloudController
  class TaskCancel
    class InvalidCancel < StandardError; end

    def initialize(user_info)
      @user_info = user_info
    end

    def cancel(task)
      reject_invalid_states!(task)

      TaskModel.db.transaction do
        task.lock!
        task.state = TaskModel::CANCELING_STATE
        task.save

        Repositories::TaskEventRepository.new(@user_info).record_task_cancel(task)
      end

      nsync_client.cancel_task(task)
    end

    private

    def reject_invalid_states!(task)
      if task.state == TaskModel::SUCCEEDED_STATE || task.state == TaskModel::FAILED_STATE
        raise InvalidCancel.new("Task state is #{task.state} and therefore cannot be canceled")
      end
    end

    def nsync_client
      CloudController::DependencyLocator.instance.nsync_client
    end
  end
end
