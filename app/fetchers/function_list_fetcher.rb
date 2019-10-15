require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'
require 'fetchers/label_selector_query_generator'

module VCAP::CloudController
  class FunctionListFetcher
    def fetch_all(eager_loaded_associations: [])
      FunctionModel.dataset.eager(eager_loaded_associations)
    end

    def fetch(space_guids, eager_loaded_associations: [])
      app_dataset = AppModel.select(:id).where(space_guid: space_guids)
      FunctionModel.dataset.where(app: app_dataset)
    end
  end
end
