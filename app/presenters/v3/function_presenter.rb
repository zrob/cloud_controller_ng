require 'presenters/mixins/metadata_presentation_helpers'
require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class FunctionPresenter < BasePresenter
    include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

    def to_hash
      {
        guid:                  function.guid,
        created_at:            function.created_at,
        updated_at:            function.updated_at,
        name:                  function.name,
        artifact:              function.artifact,
        image:                 function.image,
        git_repo:              function.git_repo,
        git_revision:          function.git_revision,
        build_status:          function.build_status,
        ready_status:          function.ready_status,
        latest_image:          function.latest_image,
        url:                   function.url,
        relationships:         {
          app: {
            data: {
              guid: function.app_guid
            }
          }
        },
        links:                 build_links
      }
    end

    private

    def function
      @resource
    end

    def build_links
      url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

      {
        self: {
          href: url_builder.build_url(path: "/v3/functions/#{function.guid}")
        },
      }
    end
  end
end
