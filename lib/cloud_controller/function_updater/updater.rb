require 'actions/process_restart'
require 'k8s-client'

module VCAP::CloudController
  module FunctionUpdater
    class Updater
      def syncify
        logger = Steno.logger('cc.function_updater.update')
        logger.info('run-function-update')

        function_client.list(labelSelector: { 'cfManaged' => 'true' }).each do |kFunction|
          ccFunction = FunctionModel.find(guid: kFunction.metadata.labels[:cfGuid])
          delete_function(kFunction) unless ccFunction
        end

        handler_client.list(labelSelector: { 'cfManaged' => 'true' }).each do |kHandler|
          ccFunction = FunctionModel.find(guid: kHandler.metadata.labels[:cfGuid])
          delete_handler(kHandler) unless ccFunction
        end

        service_client.list(labelSelector: { 'cfManaged' => 'true' }).each do |kService|
          ccFunction = FunctionModel.find(guid: kService.metadata.labels[:cfGuid])
          mapping = nil
          if !ccFunction.nil?
            mapping    = RouteMappingModel.find(function_name: ccFunction.name)
          end
          delete_service(kService) unless ccFunction && mapping
        end

        FunctionModel.each do |ccFunction|
          kFunction = get_k8s_function(ccFunction.name)
          kHandler  = get_k8s_handler(ccFunction.name)

          if kHandler.nil?
            create_handler_in_k8s(ccFunction)
          else
            update_handler_status(cc: ccFunction, k8s: kHandler)
          end

          if kFunction.nil?
            create_function_in_k8s(ccFunction)
          else
            update_function_status(cc: ccFunction, k8s: kFunction)
          end

          routes = RouteMappingModel.where(function_name: ccFunction.name).all
          routes.each do |r|
            kService = get_k8s_service("#{ccFunction.name}.#{r.guid}")
            if kService.nil?
              create_service_in_k8s(ccFunction, r)
            end
          end
        end
      end

      def create_service_in_k8s(ccFunction, mapping)
        kService = K8s::Resource.new(
          apiVersion: 'networking.istio.io/v1alpha3',
          kind:       'VirtualService',
          metadata:   {
            namespace: 'default',
            name:      "#{ccFunction.name}.#{mapping.guid}",
            labels:    {
              cfManaged:     'true',
              cfGuid:        ccFunction.guid,
              cfMappingGuid: mapping.guid,
            },
          },
          spec:       {
            gateways: ['knative-ingress-gateway.knative-serving.svc.cluster.local'],
            hosts:    ["#{mapping.route.host}.#{mapping.route.domain.name}"],
            http:     [{
              rewrite: { authority: "#{ccFunction.name}.default.example.com" },
              route:   [{
                destination: {
                  host: 'istio-ingressgateway.istio-system.svc.cluster.local'
                }
              }]
            }]
          }
        )

        service_client.create_resource(kService)
      end


      def create_function_in_k8s(ccFunction)
        kFunction = K8s::Resource.new(
          apiVersion: 'build.projectriff.io/v1alpha1',
          kind:       'Function',
          metadata:   {
            namespace: 'default',
            name:      ccFunction.name,
            labels:    {
              cfManaged: 'true',
              cfGuid:    ccFunction.guid,
            }
          },
          spec:       {
            artifact: ccFunction.artifact,
            image:    ccFunction.image,
            source:   {
              git: {
                revision: ccFunction.git_revision,
                url:      ccFunction.git_repo
              }
            }
          }
        )

        function_client.create_resource(kFunction)
      end

      def create_handler_in_k8s(ccFunction)
        env = []
        ccFunction.app.environment_variables&.each do |k, v|
          env.append({ name: k, value: v })
        end

        kFunction = K8s::Resource.new(
          apiVersion: 'knative.projectriff.io/v1alpha1',
          kind:       'Handler',
          metadata:   {
            namespace: 'default',
            name:      ccFunction.name,
            labels:    {
              cfManaged: 'true',
              cfGuid:    ccFunction.guid,
            }
          },
          spec:       {
            build:    {
              functionRef: ccFunction.name
            },
            template: {
              containers: [{ env: env }]

            }
          }
        )

        handler_client.create_resource(kFunction)
      end

      def update_function_status(cc:, k8s:)
        cc.db.transaction do
          cc.lock!

          cc.build_status        = k8s.status.conditions.select { |c| c.type == 'BuildSucceeded' }.first.status
          cc.ready_status        = k8s.status.conditions.select { |c| c.type == 'Ready' }.first.status
          cc.latest_image        = k8s.status.latestImage
          cc.observed_generation = k8s.metadata.generation

          cc.save
        end
      end

      def update_handler_status(cc:, k8s:)
        env = []
        cc.app.environment_variables&.each do |k, v|
          env.append({ name: k, value: v })
        end

        k8s.spec.template.containers.first[:env] = env

        begin
          handler_client.update_resource(k8s)
        rescue K8s::Error::Conflict
          # do nothing, next loop will get it
        end

        cc.db.transaction do
          cc.lock!
          cc.url = k8s.status.url
          cc.save
        end
      end

      def delete_handler(kHandler)
        handler_client.delete(kHandler.metadata.name)
      end

      def delete_function(kFunction)
        function_client.delete(kFunction.metadata.name)
      end

      def delete_service(kService)
        service_client.delete(kService.metadata.name)
      end

      def get_k8s_function(name)
        begin
          return function_client.get(name)
        rescue K8s::Error::NotFound
          return nil
        end
      end

      def get_k8s_handler(name)
        begin
          return handler_client.get(name)
        rescue K8s::Error::NotFound
          return nil
        end
      end

      def get_k8s_service(name)
        begin
          return service_client.get(name)
        rescue K8s::Error::NotFound
          return nil
        end
      end

      def function_client
        @fclient ||= client.api('build.projectriff.io/v1alpha1').resource('functions', namespace: 'default')
      end

      def handler_client
        @hclient ||= client.api('knative.projectriff.io/v1alpha1').resource('handlers', namespace: 'default')
      end

      def service_client
        @sclient ||= client.api('networking.istio.io/v1alpha3').resource('virtualservices', namespace: 'default')
      end

      def client
        @client ||= K8s::Client.config(
          K8s::Config.load_file(
            File.expand_path '~/.kube/config'
          )
        )
      end
    end
  end
end
