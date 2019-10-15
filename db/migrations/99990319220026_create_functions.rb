Sequel.migration do
  change do
    create_table :functions do
      VCAP::Migration.common(self)

      String :name, size: 255, null: false
      String :artifact, size: 4096, null: false
      String :image, size: 999, null: false
      String :git_repo, size: 999, null: false
      String :git_revision, size: 999, null: false
      String :build_status, size: 999, null: true
      String :ready_status, size: 999, null: true
      String :latest_image, size: 999, null: true
      String :url, size: 999, null: true
      Integer :observed_generation
      String :app_guid, size: 255, null: false

      foreign_key [:app_guid], :apps, key: :guid, name: :fk_function_app_guid
      index [:app_guid], name: :fk_function_app_guid_index
    end
  end
end
