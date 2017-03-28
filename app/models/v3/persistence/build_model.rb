module VCAP::CloudController
  class BuildModel < Sequel::Model
    BUILD_STATES = [
      STAGING_STATE = 'STAGING'.freeze,
    ].freeze

    one_to_one :droplet,
      class: 'VCAP::CloudController::DropletModel',
      key: :build_guid,
      primary_key: :guid
    
    many_to_one :space,
      class: 'VCAP::CloudController::Space',
      key: :space_guid,
      primary_key: :guid,
      without_guid_generation: true

    import_attributes :space_guid
  end
end
