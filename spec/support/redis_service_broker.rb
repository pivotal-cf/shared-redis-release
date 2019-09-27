require 'helpers/service_instance'
require 'helpers/service_broker_api'
require 'helpers/service_instances'

module Support
  class RedisServiceBroker
    def initialize(service_broker, service_name)
      @service_broker = service_broker
      @service_name = service_name
    end

    def service_instances
      service_broker.service_instances.instances
    end

    def deprovision_shared_service_instances!
      service_instances.each do |service_instance|
        puts "Found service instance #{service_instance.id.inspect}"
        service_broker.deprovision_instance(service_instance, service_name, "shared-vm")
      end
    end

    private

    attr_reader :service_broker, :service_name
  end
end
