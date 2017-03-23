module VCAP::CloudController
  RSpec.shared_examples_for 'need read scope' do |verb, method, param|

    describe 'need read scope' do
      before do
        set_current_user(VCAP::CloudController::User.new(guid: 'some-guid'), scopes: [])
      end

      context 'cloud_controller.read' do
        before do
          set_current_user(VCAP::CloudController::User.new(guid: 'some-guid'), scopes: ['cloud_controller.read'])
        end

        it 'grants reading access' do
          get :index
          expect(response.status).to eq(200)
        end

        it 'should show a specific item' do
          get :show, id: 1
          expect(response.status).to eq(204)
        end
      end

      context 'cloud_controller.admin_read_only' do
        before do
          set_current_user(VCAP::CloudController::User.new(guid: 'some-guid'), scopes: ['cloud_controller.admin_read_only'])
        end

        it 'grants reading access' do
          get :index
          expect(response.status).to eq(200)
        end

        it 'should show a specific item' do
          get :show, id: 1
          expect(response.status).to eq(204)
        end
      end

      context 'cloud_controller.global_auditor' do
        before do
          set_current_user_as_global_auditor
        end

        it 'grants reading access' do
          get :index
          expect(response.status).to eq(200)
        end

        it 'should show a specific item' do
          get :show, thing: 1
          expect(response.status).to eq(204)
        end
      end

      it 'admin can read all' do
        set_current_user_as_admin

        get :show, thing: 1
        expect(response.status).to eq(204)

        get :index
        expect(response.status).to eq(200)
      end

      context 'post' do
        before do
          set_current_user(VCAP::CloudController::User.new(guid: 'some-guid'), scopes: ['cloud_controller.write'])
        end

        it 'is not required on other actions' do
          post :create

          expect(response.status).to eq(201)
        end
      end
    end
  end
end


module VCAP::CloudController
  RSpec.shared_examples_for 'need write scope' do

    describe 'need write scope' do
      before do
        set_current_user(VCAP::CloudController::User.new(guid: 'some-guid'), scopes: ['cloud_controller.read'])
      end

      it 'is not required on index' do
        get :index
        expect(response.status).to eq(200)
      end

      it 'is not required on show' do
        get :show, id: 1
        expect(response.status).to eq(204)
      end

      it 'is required on create' do
        post :create
        expect(response.status).to eq(403)
        expect(parsed_body['errors'].first['detail']).to eq('You are not authorized to perform the requested action')
      end

      it 'is required on delete' do
        post :delete
        expect(response.status).to eq(403)
        expect(parsed_body['errors'].first['detail']).to eq('You are not authorized to perform the requested action')
      end

      it 'is not required for admin' do
        set_current_user_as_admin

        post :create
        expect(response.status).to eq(201)
      end
    end
  end
end


