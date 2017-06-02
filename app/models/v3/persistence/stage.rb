module VCAP::CloudController
  class Stage < Sequel::Model
    many_to_one :pipeline
    one_to_many :apps, class: 'VCAP::CloudController::AppModel'
  end
end