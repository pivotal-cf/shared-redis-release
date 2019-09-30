require 'system_spec_helper'
require 'helpers/bosh2_cli'

require 'socket'
require 'timeout'

describe 'security' do
  describe 'the broker' do
    it 'uses latest version of nginx' do
      output = bosh.ssh(deployment_name, Helpers::Environment::BROKER_INSTANCE_NAME, '/var/vcap/packages/cf-redis-nginx/sbin/nginx -v')
      expect(output).to eql('nginx version: nginx/1.16.1')
    end

    it 'does not listen publicly on the backend_port' do
      netstat_output = bosh.ssh(deployment_name, Helpers::Environment::BROKER_INSTANCE_NAME, "netstat -l | grep #{broker_backend_port}")
      expect(netstat_output.lines.count).to eq(1)
      expect(netstat_output).to include("localhost:#{broker_backend_port}")
    end
  end
end
