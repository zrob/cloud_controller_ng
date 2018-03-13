Sequel.migration do
  change do
    alter_table :processes do
      add_column :lrp_guid, String, size: 255, null: true
    end
  end
end
