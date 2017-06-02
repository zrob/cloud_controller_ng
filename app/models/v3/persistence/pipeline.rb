module VCAP::CloudController
  class Pipeline < Sequel::Model
    one_to_many :stages
  end  
end