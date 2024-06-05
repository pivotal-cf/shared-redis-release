require 'system_spec_helper'
require 'support/redis_service_client'
require 'system/shared_examples/redis_instance'
require 'system/shared_examples/service'
require 'helpers/bosh2_cli'

def bosh
  Helpers::Bosh2.new
end

describe 'shared plan' do
  def service_name
    redis_properties.fetch('broker').fetch('service_name')
  end

  def service_plan_name
    'shared-vm'
  end


  describe 'redis provisioning' do
    before(:all) do
      @preprovision_timestamp = bosh.ssh(deployment_name, Helpers::Environment::BROKER_JOB_NAME, 'date +%s')
      @service_instance       = service_broker.provision_instance(service_name, service_plan_name)
    end

    after(:all) do
      service_broker.deprovision_instance(@service_instance, service_name, service_plan_name)
    end

    it 'logs instance provisioning' do
      vm_log = bosh.ssh(deployment_name, Helpers::Environment::BROKER_JOB_NAME, 'sudo cat /var/vcap/sys/log/cf-redis-broker/cf-redis-broker.stdout.log')
      contains_expected_log = drop_log_lines_before(@preprovision_timestamp, vm_log).any? do |line|
        line.include?('Successfully provisioned Redis instance') &&
          line.include?('shared-vm') &&
          line.include?(@service_instance.id)
      end

      expect(contains_expected_log).to be true
    end
  end

  describe 'redis deprovisioning' do
    before(:all) do
      @service_instance = service_broker.provision_instance(service_name, service_plan_name)
      @predeprovision_timestamp = bosh.ssh(deployment_name, Helpers::Environment::BROKER_JOB_NAME, 'date +%s')
      service_broker.deprovision_instance(@service_instance, service_name, service_plan_name)
    end

    it 'logs instance deprovisioning' do
      vm_log = bosh.ssh(deployment_name, Helpers::Environment::BROKER_JOB_NAME, 'sudo cat /var/vcap/sys/log/cf-redis-broker/cf-redis-broker.stdout.log')
      contains_expected_log = drop_log_lines_before(@predeprovision_timestamp, vm_log).any? do |line|
        line.include?('Successfully deprovisioned Redis instance') &&
          line.include?('shared-vm') &&
          line.include?(@service_instance.id)
      end

      expect(contains_expected_log).to be true
    end
  end

  context 'when recreating vms' do
    before(:all) do
      @service_instance = service_broker.provision_instance(service_name, service_plan_name)
      @service_binding  = service_broker.bind_instance(@service_instance, service_name, service_plan_name)

      @service_client = service_client_builder(@service_binding)
      @service_client.write('test_key', 'test_value')
      expect(@service_client.read('test_key')).to eq('test_value')

      bosh.stop(deployment_name, Helpers::Environment::BROKER_JOB_NAME)
      bosh.recreate(deployment_name, Helpers::Environment::BROKER_JOB_NAME)
    end

    after(:all) do
      service_broker.unbind_instance(@service_binding,service_name, service_plan_name)
      service_broker.deprovision_instance(@service_instance, service_name, service_plan_name)
    end

    it 'preserves data' do
      expect(@service_client.read('test_key')).to eq('test_value')
    end
  end

  context 'when stopping the broker vm'  do
    before(:all) do
      @prestop_timestamp = bosh.ssh(deployment_name, Helpers::Environment::BROKER_JOB_NAME, 'date +%s')
      bosh.stop(deployment_name, Helpers::Environment::BROKER_JOB_NAME)
    end

    after(:all) do
      bosh.start(deployment_name, Helpers::Environment::BROKER_JOB_NAME)
    end

    it 'logs redis broker shutdown' do
      expect(bosh.eventually_contains_shutdown_log(deployment_name, Helpers::Environment::BROKER_JOB_NAME, @prestop_timestamp)).to be true
    end
  end

  it_behaves_like 'a persistent cloud foundry service'

  describe 'redis configuration' do
    before(:all) do
      @service_instance = service_broker.provision_instance(service_name, service_plan_name)
      @service_binding  = service_broker.bind_instance(@service_instance, service_name, service_plan_name)
    end

    after(:all) do
      service_broker.unbind_instance(@service_binding,service_name, service_plan_name)
      service_broker.deprovision_instance(@service_instance, service_name, service_plan_name)
    end

    describe 'configuration' do
      it 'has the correct maxclients' do
        service_client = service_client_builder(@service_binding)
        expect(service_client.config.fetch('maxclients')).to eq('10000')
      end

      it 'has the correct maxmemory' do
        maxmemory = redis_properties.fetch('maxmemory')
        service_client = service_client_builder(@service_binding)
        expect(service_client.config.fetch('maxmemory').to_i).to eq(maxmemory)
      end

      it 'runs correct version of redis' do
        service_client = service_client_builder(@service_binding)
        expect(service_client.info('redis_version')).to start_with('7.')
      end
    end

    describe 'pidfiles' do
      it 'do not appear in persistent storage' do
        output = bosh.ssh(deployment_name, Helpers::Environment::BROKER_JOB_NAME, 'sudo find /var/vcap/store/ -name "redis-server.pid" 2>/dev/null')
        expect(output).to be_empty
      end

      it 'appear in ephemeral storage' do
        ephemeral_pids = bosh.ssh(deployment_name, Helpers::Environment::BROKER_JOB_NAME, 'sudo find /var/vcap/sys/run/shared-instance-pidfiles/ -name *.pid 2>/dev/null')
        expect(ephemeral_pids.strip).to_not be_empty
        expect(ephemeral_pids.lines.length).to eq(1), "Actual output of find was: #{ephemeral_pids}"
      end
    end
  end

  context 'when redis related properties changed in the manifest' do
    def set_config_command(manifest, command='configalias')
      manifest['instance_groups'].each do |instance_group|
        next unless instance_group['name'] == 'cf-redis-broker'

        instance_group['jobs'].each do |job|
          next unless job['name'] == 'cf-redis-broker'

          job['properties']['redis']['config_command'] = command
        end
      end
    end

    before do
      bosh.redeploy(deployment_name) do |manifest|
        set_config_command(manifest)
      end

      @service_instance = service_broker.provision_instance(service_name, service_plan_name)
      @service_binding  = service_broker.bind_instance(@service_instance, service_name, service_plan_name)

      redis_client1 = service_client_builder(@service_binding)
      redis_client1.write('test', 'foobar')
      @original_config_command = redis_client1.config_command
    end

    after do
      bosh.redeploy(deployment_name) do |manifest|
        set_config_command(manifest)
      end

      service_broker.unbind_instance(@service_binding,service_name, service_plan_name)
      service_broker.deprovision_instance(@service_instance, service_name, service_plan_name)
    end

    it 'updates existing instances' do
      bosh.redeploy(deployment_name) do |manifest|
        set_config_command(manifest, 'newconfigalias')
      end

      redis_client2 = service_client_builder(@service_binding)
      new_config_command = redis_client2.config_command
      expect(new_config_command).to_not eq(@original_config_command)
      expect(redis_client2.read('test')).to eq('foobar')
    end
  end

  context 'service broker' do
    let(:admin_command_availability) do
      {
        'MONITOR' => false,
        'SAVE' => false,
        'DEBUG' => false,
        'SHUTDOWN' => false,
        'SLAVEOF' => false,
        'SYNC' => false,
        'CONFIG' => false,
        'BGSAVE' => false,
        'BGREWRITEAOF' => false,
      }
    end

    it_behaves_like 'a redis instance'
  end

  context 'when repeatedly draining a redis instance' do
    before(:all) do
      @service_instance = service_broker.provision_instance(service_name, service_plan_name)
      @service_binding  = service_broker.bind_instance(@service_instance, service_name, service_plan_name)

      ps_output = bosh.ssh(deployment_name, Helpers::Environment::BROKER_JOB_NAME, 'sudo ps aux | grep redis-serve[r]')
      expect(ps_output.strip).not_to be_empty
      expect(ps_output.lines.length).to eq(1)

      drain_command = 'sudo /var/vcap/jobs/cf-redis-broker/bin/drain'
      bosh.ssh(deployment_name, Helpers::Environment::BROKER_JOB_NAME, drain_command)
      sleep 1

      ps_output, = bosh.ssh_with_error(deployment_name, Helpers::Environment::BROKER_JOB_NAME, 'sudo ps aux | grep redis-serve[r]')
      expect(ps_output.strip).to be_empty

      bosh.ssh(deployment_name, Helpers::Environment::BROKER_JOB_NAME, 'sudo /var/vcap/bosh/bin/monit restart process-watcher')

      expect(bosh.wait_for_process_start(deployment_name, Helpers::Environment::BROKER_JOB_NAME, 'process-watcher')).to eq(true)

      bosh.ssh(deployment_name, Helpers::Environment::BROKER_JOB_NAME, drain_command)
      sleep 1
    end

    after(:all) do
      bosh.ssh(deployment_name, Helpers::Environment::BROKER_JOB_NAME, 'sudo /var/vcap/bosh/bin/monit restart process-watcher')

      expect(bosh.wait_for_process_start(deployment_name, Helpers::Environment::BROKER_JOB_NAME, 'process-watcher')).to eq(true)

      service_broker.unbind_instance(@service_binding,service_name, service_plan_name)
      service_broker.deprovision_instance(@service_instance, service_name, service_plan_name)
    end

    it 'successfuly drained the redis instance' do
      ps_output, = bosh.ssh_with_error(deployment_name, Helpers::Environment::BROKER_JOB_NAME, 'sudo ps aux | grep redis-serve[r]')
      expect(ps_output.strip).to be_empty
    end
  end

  describe 'process destroyer' do
    before do
      @service_instance = service_broker.provision_instance(service_name, service_plan_name)
      @service_binding  = service_broker.bind_instance(@service_instance, service_name, service_plan_name)

      ps_output = bosh.ssh(deployment_name, Helpers::Environment::BROKER_JOB_NAME, 'sudo ps aux | grep redis-serve[r]')
      expect(ps_output).not_to be_empty
    end

    after do
      bosh.ssh(deployment_name, Helpers::Environment::BROKER_JOB_NAME, 'sudo /var/vcap/bosh/bin/monit restart process-watcher')

      expect(bosh.wait_for_process_start(deployment_name, Helpers::Environment::BROKER_JOB_NAME, 'process-watcher')).to eq(true)

      service_broker.unbind_instance(@service_binding,service_name, service_plan_name)
      service_broker.deprovision_instance(@service_instance, service_name, service_plan_name)
    end

    it 'kills all redis-server processes when stopped' do
      bosh.ssh(deployment_name, Helpers::Environment::BROKER_JOB_NAME, 'sudo /var/vcap/bosh/bin/monit stop process-destroyer')

      bosh.wait_for_process_stop(deployment_name, Helpers::Environment::BROKER_JOB_NAME, 'process-destroyer')

      output, _, status = bosh.ssh_with_error(deployment_name, Helpers::Environment::BROKER_JOB_NAME, 'sudo ps aux | grep redis-serve[r]')
      expect(status.exitstatus).to eql 1
      expect(output).to be_empty
    end
  end
end
