module VCAP::CloudController
  module Audit
    class UserInfo
      attr_accessor :email, :guid

      def initialize(email:, guid:)
        @email = email
        @guid  = guid
      end

      def self.from_security_context(security_context)
        new(email: security_context.current_user_email, guid: security_context.current_user.try(:guid))
      end
    end
  end
end
