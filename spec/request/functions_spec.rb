require 'spec_helper'

RSpec.describe 'Functions Request' do
  describe 'GET /v3/functions' do
    let(:user) { make_user }
    let(:headers) { headers_for(user) }
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    it 'returns 200 OK' do
      get '/v3/functions', nil, headers
      expect(last_response.status).to eq(200)
    end

    context 'When functions exist' do
      let!(:function1) { VCAP::CloudController::FunctionModel.make(app: app_model) }
      let!(:function2) { VCAP::CloudController::FunctionModel.make(app: app_model) }
      let!(:function3) { VCAP::CloudController::FunctionModel.make(app: app_model) }

      it 'returns a paginated list of functions' do
        get '/v3/functions?page=1&per_page=2', nil, headers

        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 3,
              'total_pages'   => 2,
              'first'         => {
                'href' => "#{link_prefix}/v3/functions?page=1&per_page=2"
              },
              'last'          => {
                'href' => "#{link_prefix}/v3/functions?page=2&per_page=2"
              },
              'next'          => {
                'href' => "#{link_prefix}/v3/functions?page=2&per_page=2"
              },
              'previous'      => nil
            },
            'resources'  => [
              {
                'guid'                  => function1.guid,
                'created_at'            => iso8601,
                'updated_at'            => iso8601,

                'name'                  => function1.name,
                'artifact'              => function1.artifact,
                'image'                 => function1.image,
                'git_repo'              => function1.git_repo,
                'git_revision'          => function1.git_revision,
                'build_status'          => function1.build_status,
                'ready_status'          => function1.ready_status,
                'latest_image'          => function1.latest_image,
                'url'                   => function1.url,
                'relationships'         => {
                  'app' => {
                    'data' => { 'guid' => function1.app_guid } }
                },

                'links'                 => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/functions/#{function1.guid}"
                  }
                }
              },
              {
                'guid'                  => function2.guid,
                'created_at'            => iso8601,
                'updated_at'            => iso8601,

                'name'                  => function2.name,
                'artifact'              => function2.artifact,
                'image'                 => function2.image,
                'git_repo'              => function2.git_repo,
                'git_revision'          => function2.git_revision,
                'build_status'          => function2.build_status,
                'ready_status'          => function2.ready_status,
                'latest_image'          => function2.latest_image,
                'url'                   => function2.url,
                'relationships'         => {
                  'app' => {
                    'data' => { 'guid' => function2.app_guid } }
                },

                'links'                 => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/functions/#{function2.guid}"
                  }
                }
              }
            ]
          }
        )
      end
    end
  end

  describe 'GET /v3/functions/:guid' do
    let(:user) { make_user }
    let(:headers) { headers_for(user) }
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }
    let!(:function) { VCAP::CloudController::FunctionModel.make(app: app_model) }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    it 'returns details of the requested function' do
      get "/v3/functions/#{function.guid}", nil, headers

      expect(last_response.status).to eq 200
      expect(parsed_response).to be_a_response_like(
        {
          'guid'                  => function.guid,
          'created_at'            => iso8601,
          'updated_at'            => iso8601,

          'name'                  => function.name,
          'artifact'              => function.artifact,
          'image'                 => function.image,
          'git_repo'              => function.git_repo,
          'git_revision'          => function.git_revision,
          'build_status'          => function.build_status,
          'ready_status'          => function.ready_status,
          'latest_image'          => function.latest_image,
          'url'                   => function.url,
          'relationships'         => {
            'app' => {
              'data' => { 'guid' => function.app_guid } }
          },

          'links'                 => {
            'self' => {
              'href' => "#{link_prefix}/v3/functions/#{function.guid}"
            }
          }
        }
      )
    end
  end

  describe 'POST /v3/functions' do
    let(:user) { make_user }
    let(:headers) { headers_for(user) }
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    let(:request_body) do
      {
        name:                  'the-name',
        artifact:              'the-artifact',
        image:                 'the-image',
        git_repo:              'the-repo',
        git_revision:          'the-revision',
        relationships:         {
          app: {
            data: {
              guid: app_model.guid,
            }
          }
        }
      }.to_json
    end

    it 'creates a new function' do
      expect {
        post '/v3/functions', request_body, headers
      }.to change {
        VCAP::CloudController::FunctionModel.count
      }.by 1

      created_function = VCAP::CloudController::FunctionModel.last

      expect(last_response.status).to eq(201)

      expect(parsed_response).to be_a_response_like(
        {
          'guid'                  => created_function.guid,
          'created_at'            => iso8601,
          'updated_at'            => iso8601,

          'name'                  => 'the-name',
          'artifact'              => 'the-artifact',
          'image'                 => 'the-image',
          'git_repo'              => 'the-repo',
          'git_revision'          => 'the-revision',
          'build_status'          => created_function.build_status,
          'ready_status'          => created_function.ready_status,
          'latest_image'          => created_function.latest_image,
          'url'                   => created_function.url,
          'relationships'         => {
            'app' => {
              'data' => { 'guid' => created_function.app_guid } }
          },

          'links'                 => {
            'self' => {
              'href' => "#{link_prefix}/v3/functions/#{created_function.guid}"
            }
          }
        }
      )
    end
  end

  describe 'DELETE /v3/functions/:guid' do
    let(:user) { make_user }
    let(:headers) { headers_for(user) }
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }
    let!(:function) { VCAP::CloudController::FunctionModel.make(app: app_model) }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    it 'destroys the function' do
      delete "/v3/functions/#{function.guid}", {}, headers

      expect(last_response.status).to eq(204)
      expect(function).to_not exist
    end
  end
end
