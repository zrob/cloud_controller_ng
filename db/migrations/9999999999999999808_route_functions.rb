Sequel.migration do
  change do
    alter_table :route_mappings do
      add_column :function_name, String, default: nil
    end
  end
end
