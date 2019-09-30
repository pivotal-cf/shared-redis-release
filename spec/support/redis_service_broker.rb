require 'helpers/service_instance'
require 'helpers/service_broker_api'
require 'helpers/service_instances'
require 'helpers/environment'
require 'json'


def cf_cli
  Helpers::Environment::CFCLI.new
end

module Support
  class RedisServiceBroker
    def initialize(service_broker, service_name)
      @service_broker = service_broker
      @service_name = service_name
    end

    attr_reader :service_broker, :service_name
  end
end
