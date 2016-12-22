require 'cloud_controller/diego/protocol/open_process_ports'

module VCAP::CloudController
  module Diego
    module Buildpack
      class DesiredLrpBuilder
        include ::Diego::ActionBuilder

        def initialize(config, process)
          @config = config
          @process = process
        end

        def cached_dependencies
          stack = @process.stack.name
          lifecycle_bundle_key = "buildpack/#{stack}".to_sym
          [
            ::Diego::Bbs::Models::CachedDependency.new(
              from: LifecycleBundleUriGenerator.uri(@config[:diego][:lifecycle_bundles][lifecycle_bundle_key]),
              to: '/tmp/lifecycle',
              cache_key: "buildpack-#{stack}-lifecycle"
            )
          ]
        end

        def root_fs
          "preloaded:#{@process['stack']}"
        end

        def setup
          blobstore_url_generator = ::CloudController::DependencyLocator.instance.blobstore_url_generator
          serial([
            ::Diego::Bbs::Models::DownloadAction.new(
              from: blobstore_url_generator.unauthorized_perma_droplet_download_url(@process),
              to: '.',
              cache_key: "droplets-#{ProcessGuid.from_process(@process)}",
              user: 'vcap',
              checksum_algorithm: 'sha1',
              checksum_value: @process.current_droplet.droplet_hash,
            )
          ])
        end

        def global_environment_variables
          [::Diego::Bbs::Models::EnvironmentVariable.new(name: 'LANG', value: DEFAULT_LANG)]
        end

        def ports
          Diego::Protocol::OpenProcessPorts.new(@process).to_a || [DEFAULT_APP_PORT]
        end

        def privileged?
          @config[:diego][:use_privileged_containers_for_running]
        end

        def action_user
          'vcap'
        end
      end
    end
  end
end
