require 'presenters/v3/function_presenter'
require 'messages/function_create_message'
require 'messages/functions_list_message'
require 'fetchers/function_list_fetcher'

class FunctionsController < ApplicationController
  def index
    message = FunctionsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    dataset = if permission_queryer.can_read_globally?
                FunctionListFetcher.new.fetch_all
              else
                FunctionListFetcher.new.fetch(permission_queryer.readable_space_guids)
              end

    render status: :ok,
      json:        Presenters::V3::PaginatedListPresenter.new(
        presenter:        Presenters::V3::FunctionPresenter,
        paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
        path:             '/v3/functions',
        message:          message,
      )
  end

  def create
    message = FunctionCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app = AppModel.where(guid: message.app_guid).first
    unprocessable_app! unless app && permission_queryer.can_read_from_space?(app.space.guid, app.space.organization_guid) && permission_queryer.can_write_to_space?(app.space.guid)

    function = FunctionModel.create(
      {
        name:                  message.name,
        artifact:              message.artifact,
        image:                 message.image,
        git_repo:              message.git_repo,
        git_revision:          message.git_revision,
        app_guid:              message.app_guid,
      }
    )

    render status: :created, json: Presenters::V3::FunctionPresenter.new(function)
  rescue Exception => e
    unprocessable!(e.message)
  end

  def show
    function = FunctionModel.find(guid: hashed_params[:guid])
    function_not_found! unless function && permission_queryer.can_read_from_space?(function.space.guid, function.space.organization_guid)

    render status: :ok, json: Presenters::V3::FunctionPresenter.new(function)
  end

  def destroy
    function = FunctionModel.find(guid: hashed_params[:guid])
    function_not_found! unless function && permission_queryer.can_read_from_space?(function.space.guid, function.space.organization.guid)
    unauthorized! unless permission_queryer.can_write_to_space?(function.space.guid)

    function.destroy

    head :no_content
  end

  private

  def unprocessable_app!
    unprocessable!('Invalid app. Ensure that the app exists and you have access to it.')
  end

  def function_not_found!
    resource_not_found!(:function)
  end
end
