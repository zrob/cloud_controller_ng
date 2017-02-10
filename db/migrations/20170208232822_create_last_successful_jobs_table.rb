Sequel.migration do
  change do
    create_table :last_successful_jobs do
      primary_key :id
      String :name, unique: true, null: false

      Timestamp :last_completed_at, null: false, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
