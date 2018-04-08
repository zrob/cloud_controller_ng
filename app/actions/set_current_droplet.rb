module VCAP::CloudController
  class SetCurrentDroplet
    class InvalidApp < StandardError; end
    class Error < StandardError; end

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
      @logger = Steno.logger('cc.action.procfile_parse')
    end

    def update_to(app, droplet)
      unable_to_assign! unless droplet.present? && droplet_associated?(app, droplet)
      # Allow started apps to have a new droplet applied.  This facilitates zero downtime.
      #
      # app_started! if app.desired_state != ProcessModel::STOPPED
      
      assign_droplet = { droplet_guid: droplet.guid }

      app.db.transaction do
        app.lock!

        app.update(assign_droplet)

        Repositories::AppEventRepository.new.record_app_map_droplet(
          app,
          app.space,
          @user_audit_info,
          assign_droplet
        )

        setup_processes(app)

        app.save

        # Setup a process to manage the n+1 version
        #
        # This should really be a clone of the web process except for number of instances.
        # For this spike, just set healthcheck and such to what we assume for a normal web process.
        #
        # Note that ports isn't easily cloneable.  It is generally inferred later for web processes.  Proper cloning
        # would have to happen for this approach.
        # See: https://github.com/cloudfoundry/cloud_controller_ng/blob/43e0f7b95581dc11248f40861a99ecf2c5e6a6d3/lib/cloud_controller/diego/protocol/open_process_ports.rb#L15
        web_process = app.web_process
        np = ProcessCreate.new(@user_audit_info).create(app, { type: 'web-deploy', command: web_process.command, memory: 100, disk_quota: 100 })
        np.update({ instances: 1, health_check_type: 60, health_check_type: 'port', ports: [8080], state: 'STARTED' })

        # Copy routes from web process to the deploy process.
        RouteMappingModel.where(app: app, process: np).destroy
        web_process.routes.each do |route|
          message = RouteMappingsCreateMessage.new({ relationships: { process: { type: np.type } } })
          RouteMappingCreate.new(@user_audit_info, route, np).add(message)
        end

        # Create a deployment object to track work that needs to be done by 'some background process'
        deployment = Deployment.new(app_guid: app.guid, droplet_guid: droplet.guid, state: 'DEPLOYING', instances: web_process.instances)
        deployment.save
      end

      app
    rescue Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
    end

    private

    def setup_processes(app)
      CurrentProcessTypes.new(@user_audit_info).process_current_droplet(app)
    end

    def droplet_associated?(app, droplet)
      droplet.app.pk == app.pk
    end

    def unable_to_assign!
      raise Error.new('Unable to assign current droplet. Ensure the droplet exists and belongs to this app.')
    end

    def app_started!
      raise Error.new('Stop the app before changing droplet')
    end
  end
end
