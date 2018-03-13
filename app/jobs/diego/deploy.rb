module VCAP::CloudController
  class Deploy < VCAP::CloudController::Jobs::CCJob
    def perform

      Deployment.where(state: 'DEPLOYING').each do |deployment|
        app       = AppModel.find(guid: deployment.app_guid)
        og_proc   = app.processes.select { |p| p.type == 'web' }.first
        next_proc = app.processes.select { |p| p.type == 'web-deploy' }.first

        # Get the running state of the next process. Check that the expected number of processes
        # are in a RUNNING state. If the expected number of processes is not in a RUNNING state 
        # then go to the next deployment and wait for the system to converge.
        lrps         = bbs_instances_client.lrp_instances(next_proc)
        all_running  = lrps.all? { |lrp| lrp.state == 'RUNNING' }
        counts_match = lrps.count == next_proc.instances

        next unless all_running && counts_match

        # Scale the old and new processes

        if next_proc.instances == deployment.instances
          # If the deployment instances and the new process instances match, then the deployment is done.
          deployment.update(state: 'DEPLOYED')

          # Set the old process to stop running all instances and remove it
          og_proc.update(instances: 0)
          og_proc.delete

          # Set the new process to takeover the 'web' type. And set the guid to match the app guid
          # Ideally we could decouple the web process guid and app guid for a real impl.
          # Skip validations when saving otherwise weird things happen since we're cheating with process guid and 
          # type in this spike.
          next_proc.guid = app.guid
          next_proc.type = 'web'
          next_proc.save(validate: false)

        else
          # The deployment hasn't finished but is ready for the next scale operation.
          # This spike uses a simple rolling deploy algorithm. Add one of the new target instance and remove
          # one of the old instance.

          next_proc.instances = next_proc.instances + 1
          next_proc.save

          if og_proc.instances - 1 > 0
            og_proc.instances = og_proc.instances - 1
            og_proc.save
          end
        end
      end
    end

    private

    def bbs_instances_client
      CloudController::DependencyLocator.instance.bbs_instances_client
    end

    def logger
      @logger ||= Steno.logger('potato')
    end
  end
end
