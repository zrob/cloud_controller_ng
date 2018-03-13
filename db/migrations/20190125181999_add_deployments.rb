Sequel.migration do
  change do
    create_table :deployments do
      VCAP::Migration.common(self, :deployments)

      String :app_guid
      String :droplet_guid
      String :state
      Integer :instances
    end
  end
end
