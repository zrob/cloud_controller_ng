Sequel.migration do
  change do
    alter_table :builds do
      add_column :memory_in_mb, Integer
      add_column :disk_in_mb, Integer
    end
  end
end
