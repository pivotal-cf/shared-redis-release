require 'helpers/service_instance'

module Helpers
  class ServiceInstances
    def initialize(args = {})
      resources = args.fetch(:resources)
      @instances = resources.map { |instance| Helpers::ServiceInstance.new(id: resources.fetch(metadata).fetch(guid)) }
    end

    attr_reader :instances
  end
end