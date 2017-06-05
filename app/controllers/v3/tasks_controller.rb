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

class TasksController < ApplicationController
  include SubResource

  def index
    acl = VCAP::CloudController::AclServiceClient.new.get_acl(SecurityContext.current_user_name.to_sym)
    authz = VCAP::CloudController::Authz.new(acl)

    message = TasksListMessage.from_params(subresource_query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    show_secrets = false

    if app_nested?
      app, dataset = TaskListFetcher.new.fetch_for_app(message: message)
      app_not_found! unless app && authz.can_do?(app, 'task.read')
      show_secrets = authz.can_do?(app, 'app.see_secrets')
    else
      dataset = nil
      messages = authz.get_app_filter_messages(:app, 'task.read')
      messages.each do |message|
        app_dataset = TaskListFetcher.new.fetch_all(message: message)
        dataset = dataset.nil? ? app_dataset : dataset.union(app_dataset)
      end

       if dataset.nil?
         dataset = TaskModel.dataset.where(guid: 'does-not-exist_empty_dataset')
       end
    end

    render :ok, json: Presenters::V3::PaginatedListPresenter.new(
      dataset:      dataset,
      path:     base_url(resource: 'tasks'),
      message:      message,
      show_secrets: show_secrets
    )
  end

  def create
    FeatureFlag.raise_unless_enabled!(:task_creation)

    message = TaskCreateMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app, space, org, droplet = TaskCreateFetcher.new.fetch(app_guid: params[:app_guid], droplet_guid: message.droplet_guid)

    app_not_found! unless app && can_read?(space.guid, org.guid)
    unauthorized! unless can_write?(space.guid)
    droplet_not_found! if message.requested?(:droplet_guid) && droplet.nil?

    task = TaskCreate.new(configuration).create(app, message, user_audit_info, droplet: droplet)

    render status: :accepted, json: Presenters::V3::TaskPresenter.new(task)
  rescue TaskCreate::InvalidTask, TaskCreate::TaskCreateError => e
    unprocessable!(e)
  end

  def cancel
    task, space, org = TaskFetcher.new.fetch(task_guid: params[:task_guid])
    task_not_found! unless task && can_read?(space.guid, org.guid)

    unauthorized! unless can_write?(space.guid)
    TaskCancel.new(configuration).cancel(task: task, user_audit_info: user_audit_info)

    render status: :accepted, json: Presenters::V3::TaskPresenter.new(task.reload)
  rescue TaskCancel::InvalidCancel => e
    unprocessable!(e)
  end

  def show
    task, space, org = TaskFetcher.new.fetch(task_guid: params[:task_guid])
    task_not_found! unless task && can_read?(space.guid, org.guid)

    render status: :ok, json: Presenters::V3::TaskPresenter.new(task, show_secrets: can_see_secrets?(space))
  end

  private

  def task_not_found!
    resource_not_found!(:task)
  end

  def droplet_not_found!
    resource_not_found!(:droplet)
  end
end
