# frozen_string_literal: true

require 'system_spec_helper'
require 'helpers/environment'
require 'helpers/bosh2_cli'

def bosh
  Helpers::Bosh2.new
end

def service_name
  redis_properties.fetch('broker').fetch('service_name')
end

describe 'nginx' do
  describe 'configuration' do
    CONFIG_PATH = '/var/vcap/jobs/cf-redis-broker/config/nginx.conf'

    def service_plan_name
      'shared-vm'
    end

    let(:bucket_size) do
      if redis_properties['broker'].dig('nginx', 'bucket_size').nil?
        128
      else
        redis_properties['broker'].dig('nginx', 'bucket_size')
      end
    end

    before(:all) do
      @service_instance = service_broker.provision_instance(service_name, service_plan_name)
      @binding = service_broker.bind_instance(@service_instance, service_name, service_plan_name)
    end

    after(:all) do
      service_broker.unbind_instance(@binding, service_name, service_plan_name)
      service_broker.deprovision_instance(@service_instance, service_name, service_plan_name)
    end

    it 'has the correct server_names_hash_bucket_size' do
      expect(bucket_size).to be > 0
      command = %(sudo grep "server_names_hash_bucket_size #{bucket_size}" #{CONFIG_PATH})
      result = bosh.ssh(deployment_name, "#{Helpers::Environment::BROKER_INSTANCE_NAME}/0", command)
      expect(result.strip).not_to be_empty
    end
  end
end
