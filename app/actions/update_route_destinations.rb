module VCAP::CloudController
  class UpdateRouteDestinations
    class Error < StandardError
    end

    class << self
      def add(new_route_mappings, route, apps_hash, user_audit_info, manifest_triggered: false)
        existing_route_mappings = route_to_mapping_hashes(route)
        new_route_mappings = update_port(new_route_mappings, apps_hash)
        new_route_mappings = add_route(new_route_mappings, route)
        if existing_route_mappings.any? { |rm| rm[:weight] }
          raise Error.new('Destinations cannot be inserted when there are weighted destinations already configured.')
        end

        to_add = new_route_mappings - existing_route_mappings

        update(route, to_add, [], user_audit_info, manifest_triggered)
      end

      def replace(new_route_mappings, route, apps_hash, user_audit_info, manifest_triggered: false)
        existing_route_mappings = route_to_mapping_hashes(route)
        new_route_mappings = update_port(new_route_mappings, apps_hash)
        new_route_mappings = add_route(new_route_mappings, route)
        to_add = new_route_mappings - existing_route_mappings
        to_delete = existing_route_mappings - new_route_mappings

        update(route, to_add, to_delete, user_audit_info, manifest_triggered)
      end

      def delete(destination, route, user_audit_info)
        if destination.weight
          raise Error.new('Weighted destinations cannot be deleted individually.')
        end

        to_delete = [destination_to_mapping_hash(route, destination)]

        update(route, [], to_delete, user_audit_info, false)
      end

      private

      def update(route, to_add, to_delete, user_audit_info, manifest_triggered)
        RouteMappingModel.db.transaction do
          processes_to_ports_map = {}

          to_delete.each do |rm|
            route_mapping = RouteMappingModel.find(rm)
            route_mapping.destroy

            Copilot::Adapter.unmap_route(route_mapping)
            route_mapping.processes.each do |process|
              processes_to_ports_map[process] ||= { to_add: [], to_delete: [] }
              processes_to_ports_map[process][:to_delete] << route_mapping.app_port unless process.route_mappings.any? do |process_route_mapping|
                process_route_mapping.guid != route_mapping.guid && process_route_mapping.app_port == route_mapping.app_port
              end
            end

            Repositories::AppEventRepository.new.record_unmap_route(
              user_audit_info,
              route_mapping,
              manifest_triggered: manifest_triggered
            )
          end

          to_add.each do |rm|
            route_mapping = RouteMappingModel.new(rm)
            route_mapping.save

            Copilot::Adapter.map_route(route_mapping)
            route_mapping.processes.each do |process|
              processes_to_ports_map[process] ||= { to_add: [], to_delete: [] }
              processes_to_ports_map[process][:to_add] << route_mapping.app_port
            end

            Repositories::AppEventRepository.new.record_map_route(
              user_audit_info,
              route_mapping,
              manifest_triggered: manifest_triggered
            )
          end

          update_processes(processes_to_ports_map)
        end

        route.reload
      end

      def update_processes(processes_to_ports_map)
        processes_to_ports_map.each do |process, ports_hash|
          ports_to_add = ports_hash[:to_add].uniq.reject { |port| port == ProcessModel::NO_APP_PORT_SPECIFIED }
          ports_to_delete = ports_hash[:to_delete].uniq.reject { |port| port == ProcessModel::NO_APP_PORT_SPECIFIED }

          updated_ports = ((process.ports || []) + ports_to_add - ports_to_delete).uniq
          if updated_ports.empty?
            updated_ports = if process.app.buildpack?
                              ProcessModel::DEFAULT_PORTS
                            end
          end

          ProcessRouteHandler.new(process).update_route_information(
            perform_validation: false,
            updated_ports: updated_ports
          )
        end
      rescue Sequel::ValidationFailed => e
        raise Error.new(e.message)
      end

      def add_route(destinations, route)
        destinations.map do |dst|
          dst.merge({ route: route, route_guid: route.guid })
        end
      end

      def update_port(destinations, apps_hash)
        destinations.each do |dst|
          if dst[:app_port].nil?
            app = apps_hash[dst[:app_guid]]

            dst[:app_port] = default_port(app)
          end
        end
      end

      def default_port(app)
        if app.buildpack?
          ProcessModel::DEFAULT_HTTP_PORT
        else
          ProcessModel::NO_APP_PORT_SPECIFIED
        end
      end

      def route_to_mapping_hashes(route)
        route.route_mappings.map do |destination|
          destination_to_mapping_hash(route, destination)
        end
      end

      def destination_to_mapping_hash(route, destination)
        {
          app_guid: destination.app_guid,
          route_guid: destination.route_guid,
          process_type: destination.process_type,
          app_port: destination.app_port,
          route: route,
          weight: destination.weight,
          function_name: destination.function_name
        }
      end
    end
  end
end
