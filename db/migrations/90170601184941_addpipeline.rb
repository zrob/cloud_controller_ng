Sequel.migration do
  change do
    create_table :pipelines do
      VCAP::Migration.common(self)
      String :name
    end

    create_table :stages do
      VCAP::Migration.common(self)
      String :name
      Integer :pipeline_id
    end

    alter_table :apps do
      add_column :stage_id, Integer
    end
  end
end
