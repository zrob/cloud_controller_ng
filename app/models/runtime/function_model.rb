module VCAP::CloudController
  class FunctionModel < Sequel::Model(:functions)
    include Serializer

    many_to_one :app, class: 'VCAP::CloudController::AppModel', key: :app_guid, primary_key: :guid, without_guid_generation: true

    one_through_one :space,
      join_table:        AppModel.table_name,
      left_primary_key:  :app_guid, left_key: :guid,
      right_primary_key: :guid, right_key: :space_guid
  end
end
