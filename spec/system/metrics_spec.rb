require 'system_spec_helper'

describe 'metrics', :skip_metrics => true do

  before do
    @number_of_nodes = test_manifest['instance_groups'].select do |instance_group|
      instance_group['name'] == Helpers::Environment::DEDICATED_NODE_JOB_NAME
    end.first['instances']
    @origin_tag = test_manifest['properties']['service_metrics']['origin']
    @outFile = Tempfile.new('smetrics')
    cf_target
    cf_login
    @pid = spawn(
      "cf log-stream",
      [:out, :err] => [@outFile.path, 'w']
    )
  end

  after do
    Process.kill('INT', @pid)
    @outFile.unlink
  end

  describe 'broker metrics' do
    %w[_p_redis_service_broker_dedicated_vm_plan/total_instances
       _p_redis_service-broker_dedicated_vm_plan_available_instances
       _p_redis_service-broker_shared_vm_plan_available_instances
       _p_redis_service-broker_shared_vm_plan_total_instances].each do |metric_name|
      it "contains #{metric_name} metric for redis broker" do
        assert_metric(metric_name, Helpers::Environment::BROKER_JOB_NAME, 0)
      end
    end
  end

  describe 'redis metrics' do
    %w[_p_redis_info_cpu_used_cpu_sys
       _p_redis_info_memory_used_memory
       _p_redis_info_memory_maxmemory
       _p_redis_info_stats_total_commands_processed
       _p_redis_info_stats_total_connections_received
       _p_redis_info_memory_mem_fragmentation_ratio
       _p_redis_info_stats_evicted_keys
       _p_redis_info_server_uptime_in_seconds
       _p_redis_info_server_uptime_in_days
       _p_redis_info_persistence_rdb_last_bgsave_status].each do |metric_name|
      it "contains #{metric_name} metric for all dedicated nodes" do
        @number_of_nodes.times do |idx|
          assert_metric(metric_name, Helpers::Environment::DEDICATED_NODE_JOB_NAME, idx)
        end
      end
    end
  end

  def assert_metric(metric_name, job_name, job_index)
    metric = find_metric(metric_name, job_name, job_index)

    expect(metric).to match(/"value":\d+/)
    expect(metric).to include("\"origin\":\"#{@origin_tag}\"")
    expect(metric).to include("\"deployment\":\"#{deployment_name}\"")
    expect(metric).to match(/"timestamp":"\d+"/)
    expect(metric).to match(/"index":"[\dabcdef-]*"/)
    expect(metric).to match(/"ip":"\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"/)
  end

  def find_metric(metric_name, job_name, job_index)
    job_id = loggregator_agent_id_from_job_index(job_name, job_index)
    60.times do
      File.open(rlp_gateway_out_file, 'r') do |file|
        regex = /(?=.*"job":"#{job_name}")(?=.*"index":"#{job_id}")(?=.*"#{metric_name}")/
        matches = file.readlines.grep(regex)
        return matches[0] unless matches.empty?
      end
      sleep 1
    end
    raise("metric '#{metric_name}' for job '#{job_name}' with index '#{job_id}' not found")
  end

  def loggregator_agent_id_from_job_index(job_name, job_index)
    bosh.ssh(deployment_name,
             "#{job_name}/#{job_index}",
             'sudo cat /var/vcap/jobs/loggregator_agent/config/bpm.yml | grep AGENT_INDEX | cut -d \" -f2')
  end

  def rlp_gateway_out_file
    @outFile.path
  end
end
