Sequel.migration do
  change do
    alter_table :builds do
      add_column :space_guid, String, null: false
      add_foreign_key [:space_guid], :spaces, key: :guid, name: :fk_builds_space_guid
    end
  end
end
