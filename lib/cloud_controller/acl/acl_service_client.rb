module VCAP::CloudController
  class AclServiceClient
    def get_acl(user_id)
      response = http_client.get(get_acl_endpoint(user_id))
      body = response.body == '""' ? '{}' : response.body

      acl_statements = JSON.parse(body).fetch('accessControlEntries', []).map do |ace|
        {
          'resource' => ace['resourceUrn'],
          'action' => ace['action'],
        }
      end

      acl_data = {
        'foundation_id' => ACL::FOUNDATION_ID,
        'statements' => acl_statements,
      }.deep_symbolize_keys

      ACL.new(acl_data)
    end

    private

    def http_client
      @http_client ||= HTTPClient.new
    end

    def get_acl_endpoint(user_id)
      "https://acl-service.cfapps.io/acls/#{user_id}"
    end
  end
end
