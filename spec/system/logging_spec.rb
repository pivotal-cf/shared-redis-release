require 'logger'
require 'system_spec_helper'
require 'rspec/eventually'

describe 'logging' do
  SYSLOG_FILE = "/var/log/syslog"

  describe 'syslog-forwarding' do
    let(:syslog_helper) { get_syslog_endpoint_helper }

    before do
      syslog_helper.drain
    end

    context 'cf-redis-broker' do
      before do
        bosh.ssh(deployment_name, Helpers::Environment::BROKER_JOB_NAME, "sudo /var/vcap/bosh/bin/monit restart #{Helpers::Environment::BROKER_JOB_NAME}")
        expect(bosh.wait_for_process_start(deployment_name, Helpers::Environment::BROKER_JOB_NAME, Helpers::Environment::BROKER_JOB_NAME)).to be true
        expect(bosh.wait_for_process_start(deployment_name, Helpers::Environment::BROKER_JOB_NAME, Helpers::Environment::METRICS_JOB_NAME)).to be true
      end

      it 'forwards logs' do
        expect { syslog_helper.get_line }.to eventually(include Helpers::Environment::BROKER_JOB_NAME).within 5
      end
    end
  end

  describe 'redis broker' do
    before(:all) do
      bosh.ssh(deployment_name, Helpers::Environment::BROKER_JOB_NAME, "sudo /var/vcap/bosh/bin/monit restart #{Helpers::Environment::BROKER_JOB_NAME}")
      expect(bosh.wait_for_process_start(deployment_name, Helpers::Environment::BROKER_JOB_NAME, Helpers::Environment::BROKER_JOB_NAME)).to be true
      expect(bosh.wait_for_process_start(deployment_name, Helpers::Environment::BROKER_JOB_NAME, Helpers::Environment::METRICS_JOB_NAME)).to be true
    end

    it 'allows log access via bosh' do
      expected_log_files = %w[
          access.log
          cf-redis-broker.stderr.log
          cf-redis-broker.stdout.log
          error.log
          nginx.stderr.log
          nginx.stdout.log
          process-watcher.stderr.log
          process-watcher.stdout.log
        ]

      log_paths = bosh.log_files(deployment_name, Helpers::Environment::BROKER_JOB_NAME)
      expect(log_paths.map(&:basename).map(&:to_s)).to include(*expected_log_files)
    end
  end
end

def count_from_log(deployment_name, instance, pattern, log_file)
  output = bosh.ssh(deployment_name, instance, %(sudo grep -v grep #{log_file} | grep -c "#{pattern}"))
  Integer(output.strip)
end
