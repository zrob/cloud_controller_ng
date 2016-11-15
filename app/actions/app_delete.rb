require 'jobs/runtime/blobstore_delete.rb'
require 'jobs/v3/buildpack_cache_delete'
require 'actions/package_delete'
require 'actions/task_delete'
require 'actions/droplet_delete'
require 'actions/process_delete'
require 'actions/route_mapping_delete'

module VCAP::CloudController
  class AppDelete
    class InvalidDelete < StandardError; end

    def initialize(user_info)
      @user_info = user_info
      @logger    = Steno.logger('cc.action.app_delete')
    end

    def delete(apps, record_event: true)
      apps = Array(apps)

      apps.each do |app|
        app.db.transaction do
          app.lock!

          delete_subresources(app)

          record_audit_event(app) if record_event

          app.destroy
        end
      end
    end

    def delete_without_event(apps)
      delete(apps, record_event: false)
    end

    private

    def record_audit_event(app)
      Repositories::AppEventRepository.new(@user_info).record_app_delete_request(
        app,
        app.space
      )
    end

    def delete_subresources(app)
      PackageDelete.new(@user_info.guid, @user_info.email).delete(app.packages)
      TaskDelete.new(@user_info).delete(app.tasks)
      DropletDelete.new(@user_info.guid, @user_info.email, stagers).delete(app.droplets)
      ProcessDelete.new(@user_info).delete(app.processes)
      RouteMappingDelete.new(@user_info).delete(route_mappings_to_delete(app))
      ServiceBindingDelete.new(@user_info).delete(app.service_bindings)
      delete_buildpack_cache(app)
    end

    def stagers
      CloudController::DependencyLocator.instance.stagers
    end

    def route_mappings_to_delete(app)
      RouteMappingModel.where(app_guid: app.guid)
    end

    def delete_buildpack_cache(app)
      delete_job = Jobs::V3::BuildpackCacheDelete.new(app.guid)
      Jobs::Enqueuer.new(delete_job, queue: 'cc-generic').enqueue
    end
  end
end
