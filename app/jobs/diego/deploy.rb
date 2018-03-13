module VCAP::CloudController
  class Deploy < VCAP::CloudController::Jobs::CCJob
    def perform

      Deployment.where(state: 'DEPLOYING').each do |deployment|
        app       = AppModel.find(guid: deployment.app_guid)
        og_proc   = app.processes.select { |p| p.type == 'web' }.first
        next_proc = app.processes.select { |p| p.type == 'web-deploy' }.first

        lrps         = bbs_instances_client.lrp_instances(next_proc)
        all_running  = lrps.all? { |lrp| lrp.state == 'RUNNING' }
        counts_match = lrps.count == next_proc.instances

        next unless all_running && counts_match

        if next_proc.instances == deployment.instances
          deployment.update(state: 'DEPLOYED')

          og_proc.update(instances: 0)
          og_proc.delete

          next_proc.guid = app.guid
          next_proc.type = 'web'
          next_proc.save(validate: false)
        else
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
