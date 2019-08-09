require 'system_spec_helper'

describe 'security' do
  describe 'the broker' do
    it 'uses latest version of nginx' do
      output = bosh.ssh(deployment_name, Helpers::Environment::BROKER_JOB_NAME, '/var/vcap/packages/cf-redis-nginx/sbin/nginx -v')
      expect(output).to eql('nginx version: nginx/1.8.0')
    end
  end
end
