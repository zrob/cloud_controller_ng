require 'json'
require 'yaml'
require 'httpclient'

acl_data = YAML.load_file('/Users/pivotal/workspace/cf-release/src/capi-release/src/cloud_controller_ng/config/acls/tasks-acl.yml')
acl_client = HTTPClient.new

acl_data['acls'].each do |user, user_acl|
  acl_statements = user_acl['statements'].map do |ace|
    {
      'resourceUrn' => ace['resource'],
      'action' => ace['action'],
    }
  end
  body = {
    'userId' => user,
    'acl' => acl_statements,
  }

  response = acl_client.post("https://acl-service.cfapps.io/acls", body.to_json, {'Content-Type' => 'application/json' })
  puts response.body
end
