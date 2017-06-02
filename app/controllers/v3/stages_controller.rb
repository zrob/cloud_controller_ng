require 'fetchers/app_fetcher'
require 'fetchers/task_list_fetcher'
require 'fetchers/task_create_fetcher'
require 'fetchers/task_fetcher'
require 'actions/task_create'
require 'actions/task_cancel'
require 'messages/tasks/task_create_message'
require 'messages/tasks/tasks_list_message'
require 'presenters/v3/task_presenter'
require 'controllers/v3/mixins/sub_resource'

class StagesController < ApplicationController
  def create
    stage = Stage.create(
      name:     params[:name],
      pipeline: Pipeline.find(guid: params[:pipeline_guid])
    )

    render status: :created, json: StagePresenter.new(stage)
  end

  class StagePresenter
    def initialize(pipeline)
      @pipeline=pipeline
    end

    def to_hash
      {
        guid: @pipeline.guid,
        name: @pipeline.name,
      }
    end
  end
end
