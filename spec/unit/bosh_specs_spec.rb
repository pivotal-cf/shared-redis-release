require 'yaml'

PROJECT_ROOT = File.join(File.dirname(__FILE__), '..', '..')
BROKER_SPEC_PATH = File.join(PROJECT_ROOT, 'jobs/cf-redis-broker/spec')

describe 'bosh specs' do
  describe 'cf-redis-broker' do
    subject { YAML.load_file(BROKER_SPEC_PATH) }

    it 'is configured to provide a bosh link' do
      expected_link = {
        'name' => 'redis_broker',
        'type' => 'redis_broker',
        'properties' => [
          'redis.broker.name',
          'redis.broker.nginx.port',
          'redis.broker.auth.username',
          'redis.broker.auth.password'
        ]
      }

      expect(subject['provides']).to include(expected_link)
    end
  end
end
