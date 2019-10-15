require 'spec_helper'
require 'cloud_controller/function_updater/updater'

module VCAP::CloudController
  RSpec.describe FunctionUpdater::Updater do
    subject(:updater) { FunctionUpdater::Updater.new }

    let(:client) do
      K8s::Client.config(
        K8s::Config.load_file(
          File.expand_path '~/.kube/config'
        )
      )
    end
    let(:function_client) do
      client.api('build.projectriff.io/v1alpha1').resource('functions', namespace: 'default')
    end
    let(:handler_client) do
      client.api('knative.projectriff.io/v1alpha1').resource('handlers', namespace: 'default')
    end
    let(:service_client) do
      client.api('networking.istio.io/v1alpha3').resource('virtualservices', namespace: 'default')
    end

    let(:app_model) { AppModel.make(environment_variables: { hello: 'world' }) }

    let(:ccFunction_to_add) { FunctionModel.make(app: app_model) }
    let(:ccFunction_to_keep) { FunctionModel.make }
    let(:ccFunction_to_update) { FunctionModel.make }

    let(:kFunction_to_keep_name) { ccFunction_to_keep.name }
    let(:kFunction_to_keep) do
      K8s::Resource.new(
        apiVersion: 'build.projectriff.io/v1alpha1',
        kind:       'Function',
        metadata:   {
          namespace: 'default',
          name:      kFunction_to_keep_name,
          labels:    {
            cfManaged: 'true',
            cfGuid:    ccFunction_to_keep.guid,
          },
        },
        spec:       {
          artifact: 'artifact',
          image:    'image',
          source:   {
            git: {
              revision: 'revision',
              url:      'repo'
            }
          }
        }
      )
    end
    let(:kFunction_to_remove_name) { 'remove-me' }
    let(:kFunction_to_remove) do
      K8s::Resource.new(
        apiVersion: 'build.projectriff.io/v1alpha1',
        kind:       'Function',
        metadata:   {
          namespace: 'default',
          name:      kFunction_to_remove_name,
          labels:    {
            cfManaged: 'true',
            cfGuid:    'some-guid',
          },
        },
        spec:       {
          artifact: 'artifact',
          image:    'image',
          source:   {
            git: {
              revision: 'revision',
              url:      'repo'
            }
          }
        }
      )
    end
    let(:kFunction_to_update_name) { ccFunction_to_update.name }
    let(:kFunction_to_update) do
      K8s::Resource.new(
        apiVersion: 'build.projectriff.io/v1alpha1',
        kind:       'Function',
        metadata:   {
          namespace: 'default',
          name:      kFunction_to_update_name,
          labels:    {
            cfManaged: 'true',
            cfGuid:    ccFunction_to_update.guid,
          },
        },
        spec:       {
          artifact: 'artifact',
          image:    'image',
          source:   {
            git: {
              revision: 'revision',
              url:      'repo'
            }
          }
        }
      )
    end

    let(:kHandler_to_keep_name) { ccFunction_to_keep.name }
    let(:kHandler_to_keep) do
      K8s::Resource.new(
        apiVersion: 'knative.projectriff.io/v1alpha1',
        kind:       'Handler',
        metadata:   {
          namespace: 'default',
          name:      kHandler_to_keep_name,
          labels:    {
            cfManaged: 'true',
            cfGuid:    ccFunction_to_keep.guid,
          },
        },
        spec:       {
          build: {
            functionRef: kHandler_to_keep_name
          }
        }
      )
    end
    let(:kHandler_to_remove_name) { 'remove-me' }
    let(:kHandler_to_remove) do
      K8s::Resource.new(
        apiVersion: 'knative.projectriff.io/v1alpha1',
        kind:       'Handler',
        metadata:   {
          namespace: 'default',
          name:      kHandler_to_remove_name,
          labels:    {
            cfManaged: 'true',
            cfGuid:    'some-guid',
          },
        },
        spec:       {
          build: {
            functionRef: kHandler_to_remove_name
          }
        }
      )
    end
    let(:kHandler_to_update_name) { ccFunction_to_update.name }
    let(:kHandler_to_update) do
      K8s::Resource.new(
        apiVersion: 'knative.projectriff.io/v1alpha1',
        kind:       'Handler',
        metadata:   {
          namespace: 'default',
          name:      kHandler_to_update_name,
          labels:    {
            cfManaged: 'true',
            cfGuid:    ccFunction_to_update.guid,
          },
        },
        spec:       {
          build: {
            functionRef: kHandler_to_update_name
          }
        }
      )
    end

    let(:kService_to_keep_name) { ccFunction_to_keep.name }
    let(:kService_to_keep) do
      K8s::Resource.new(
        apiVersion: 'networking.istio.io/v1alpha3',
        kind:       'VirtualService',
        metadata:   {
          namespace: 'default',
          name:      kService_to_keep_name,
          labels:    {
            cfManaged: 'true',
            cfGuid:    ccFunction_to_keep.guid,
          },
        }
      )
    end
    let(:kService_to_remove_name) { 'remove-me' }
    let(:kService_to_remove) do
      K8s::Resource.new(
        apiVersion: 'networking.istio.io/v1alpha3',
        kind:       'VirtualService',
        metadata:   {
          namespace: 'default',
          name:      kService_to_remove_name,
          labels:    {
            cfManaged: 'true',
            cfGuid:    'some-guid',
          },
        }
      )
    end

    let(:app) { AppModel.make(space: ccFunction_to_add.space) }
    let(:route1) { Route.make(space: ccFunction_to_add.space) }
    let(:route2) { Route.make(space: ccFunction_to_add.space) }
    let(:route_mapping1) { RouteMappingModel.create(app_guid: app.guid, route_guid: route1.guid, function_name: ccFunction_to_add.name, app_port: 8080) }
    let(:route_mapping2) { RouteMappingModel.create(app_guid: app.guid, route_guid: route2.guid, function_name: ccFunction_to_add.name, app_port: 8080) }

    before do
      WebMock.allow_net_connect!

      begin
        function_client.delete(kFunction_to_remove_name)
      rescue K8s::Error::NotFound
      end

      begin
        function_client.delete(kFunction_to_keep_name)
      rescue K8s::Error::NotFound
      end

      begin
        function_client.delete(kFunction_to_update_name)
      rescue K8s::Error::NotFound
      end

      begin
        function_client.delete(ccFunction_to_add.name)
      rescue K8s::Error::NotFound
      end

      begin
        handler_client.delete(kHandler_to_remove_name)
      rescue K8s::Error::NotFound
      end

      begin
        handler_client.delete(kHandler_to_keep_name)
      rescue K8s::Error::NotFound
      end

      begin
        handler_client.delete(kHandler_to_update_name)
      rescue K8s::Error::NotFound
      end

      begin
        handler_client.delete(ccFunction_to_add.name)
      rescue K8s::Error::NotFound
      end

      begin
        service_client.delete(kService_to_remove_name)
      rescue K8s::Error::NotFound
      end

      begin
        service_client.delete(kService_to_keep_name)
      rescue K8s::Error::NotFound
      end

      begin
        service_client.delete(ccFunction_to_add.name)
      rescue K8s::Error::NotFound
      end


      begin
        service_client.delete("#{ccFunction_to_add.name}.#{route_mapping1.guid}")
      rescue K8s::Error::NotFound
      end
      begin
        service_client.delete("#{ccFunction_to_add.name}.#{route_mapping2.guid}")
      rescue K8s::Error::NotFound
      end


      function_client.create_resource(kFunction_to_remove)
      function_client.create_resource(kFunction_to_keep)
      function_client.create_resource(kFunction_to_update)
      handler_client.create_resource(kHandler_to_remove)
      handler_client.create_resource(kHandler_to_keep)
      handler_client.create_resource(kHandler_to_update)
      service_client.create_resource(kService_to_remove)
      service_client.create_resource(kService_to_keep)
    end

    after do
      begin
        function_client.delete(kFunction_to_remove_name)
      rescue K8s::Error::NotFound
      end

      begin
        function_client.delete(kFunction_to_keep_name)
      rescue K8s::Error::NotFound
      end

      begin
        function_client.delete(kFunction_to_update_name)
      rescue K8s::Error::NotFound
      end

      begin
        function_client.delete(ccFunction_to_add.name)
      rescue K8s::Error::NotFound
      end

      begin
        handler_client.delete(kHandler_to_remove_name)
      rescue K8s::Error::NotFound
      end

      begin
        handler_client.delete(kHandler_to_keep_name)
      rescue K8s::Error::NotFound
      end

      begin
        handler_client.delete(kHandler_to_update_name)
      rescue K8s::Error::NotFound
      end

      begin
        handler_client.delete(ccFunction_to_add.name)
      rescue K8s::Error::NotFound
      end

      begin
        service_client.delete(kService_to_remove_name)
      rescue K8s::Error::NotFound
      end

      begin
        service_client.delete(kService_to_keep_name)
      rescue K8s::Error::NotFound
      end

      begin
        service_client.delete(ccFunction_to_add.name)
      rescue K8s::Error::NotFound
      end


      begin
        service_client.delete("#{ccFunction_to_add.name}.#{route_mapping1.guid}")
      rescue K8s::Error::NotFound
      end
      begin
        service_client.delete("#{ccFunction_to_add.name}.#{route_mapping2.guid}")
      rescue K8s::Error::NotFound
      end

    end

    it 'removes functions from k8s that are not in cc' do
      updater.syncify

      expect { function_client.get(kFunction_to_remove_name) }.to raise_error(K8s::Error::NotFound)
    end

    it 'does not remove functions from k8s that are in cc' do
      updater.syncify

      expect(function_client.get(kFunction_to_keep_name).metadata.labels[:cfGuid]).to eq(ccFunction_to_keep.guid)
    end

    it 'adds cc functions to k8s' do
      expect { function_client.get(ccFunction_to_add.name) }.to raise_error(K8s::Error::NotFound)
      updater.syncify
      expect(function_client.get(ccFunction_to_add.name).metadata.labels[:cfGuid]).to eq(ccFunction_to_add.guid)
    end

    it 'updates cc functions with info from k8s function status' do
      expect(ccFunction_to_update.reload.build_status).to be_nil
      updater.syncify
      expect(ccFunction_to_update.reload.build_status).not_to be_nil
    end


    it 'removes handlers from k8s that are not in cc' do
      updater.syncify

      expect { handler_client.get(kHandler_to_remove_name) }.to raise_error(K8s::Error::NotFound)
    end

    it 'does not remove handler from k8s that are in cc' do
      updater.syncify

      expect(handler_client.get(kHandler_to_keep_name).metadata.labels[:cfGuid]).to eq(ccFunction_to_keep.guid)
    end

    it 'adds handlers to k8s for cc functions' do
      expect { handler_client.get(ccFunction_to_add.name) }.to raise_error(K8s::Error::NotFound)
      updater.syncify

      expect(handler_client.get(ccFunction_to_add.name).metadata.labels[:cfGuid]).to eq(ccFunction_to_add.guid)
      expect(
        handler_client.get(ccFunction_to_add.name).spec.template.containers.first.env.select { |i| i[:name] == 'hello' }.first.value
      ).to eq(ccFunction_to_add.app.environment_variables['hello'])
    end

    it 'updates cc functions with info from k8s handler status' do
      expect(ccFunction_to_update.reload.url).to be_nil
      sleep 10
      updater.syncify
      expect(ccFunction_to_update.reload.url).not_to be_nil
    end


    it 'removes virtual service from k8s that are not in cc' do
      updater.syncify

      expect { service_client.get(kService_to_remove_name) }.to raise_error(K8s::Error::NotFound)
    end

    it 'does not remove service from k8s that are in cc' do
      updater.syncify

      expect(service_client.get(kService_to_keep_name).metadata.labels[:cfGuid]).to eq(ccFunction_to_keep.guid)
    end

    it 'adds services to k8s for cc functions with routes' do
      expect { service_client.get("#{ccFunction_to_add.name}.#{route_mapping1.guid}") }.to raise_error(K8s::Error::NotFound)
      expect { service_client.get("#{ccFunction_to_add.name}.#{route_mapping2.guid}") }.to raise_error(K8s::Error::NotFound)
      updater.syncify

      expect(service_client.get("#{ccFunction_to_add.name}.#{route_mapping1.guid}").metadata.labels[:cfGuid]).to eq(ccFunction_to_add.guid)
      expect(service_client.get("#{ccFunction_to_add.name}.#{route_mapping2.guid}").metadata.labels[:cfGuid]).to eq(ccFunction_to_add.guid)


    end
  end
end
