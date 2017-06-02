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

class PipelinesController < ApplicationController
  def create
    pipeline = Pipeline.create(
      name: params[:name],
    )
    pipeline.add_stage(Stage.create(name: 'dev'))
    pipeline.add_stage(Stage.create(name: 'prod'))

    render status: :created, json: PipelinePresenter.new(pipeline)
  end

  def show
    pipeline = Pipeline.find(guid: params[:pipeline_guid])
    if pipeline == nil
      pipeline = Pipeline.find(name: params[:pipeline_guid])      
    end
    
    render status: :created, json: PipelinePresenter.new(pipeline)
  end


  def add_app
    pipeline = Pipeline.find(guid: params[:pipeline_guid])
    stage    = pipeline.stages.find {|s| s.name == params[:stage]}
    app      = AppModel.find(guid: params[:app_guid])
    stage.add_app(app)

    head :no_content
  end

  def promote
    pipeline = Pipeline.find(guid: params[:pipeline_guid])

    from_app = pipeline.stages.find {|s| s.name == 'dev'}.apps.first
    to_apps  = pipeline.stages.find {|s| s.name == 'prod'}.apps

    copier = DropletCopy.new(from_app.droplet)

    to_apps.each do |dest_app|
      new_droplet = copier.copy(dest_app, user_audit_info)

      while new_droplet.reload.state != 'STAGED'
        sleep 1
      end

      AppStop.stop(app: dest_app, user_audit_info: nil, record_event: false)
      SetCurrentDroplet.new(user_audit_info).update_to(dest_app, new_droplet)
      AppStart.start(app: dest_app, user_audit_info: nil, record_event: false)
    end

    head :no_content
  end
  

  class PipelinePresenter
    def initialize(pipeline)
      @pipeline=pipeline
    end

    def to_hash
      {
        guid:   @pipeline.guid,
        name:   @pipeline.name,
        stages: @pipeline.stages.collect {|s| StagePresenter.new(s).to_hash}
      }
    end
  end


  class StagePresenter
    def initialize(stage)
      @stage=stage
    end

    def to_hash
      {
        guid: @stage.guid,
        name: @stage.name,
        apps: @stage.apps.collect {|s| AppPresenter.new(s).to_hash}
      }
    end
  end

  class AppPresenter
    def initialize(app)
      @app=app
    end

    def to_hash
      {
        guid: @app.guid,
        name: @app.name,
      }
    end
  end

  private

  def task_not_found!
    resource_not_found!(:task)
  end

  def droplet_not_found!
    resource_not_found!(:droplet)
  end
end
