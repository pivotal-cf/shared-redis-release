# frozen_string_literal: true

require 'helpers/service_instance'

module Helpers
  class ServiceInstances
    def initialize(args = {})
      resources = args['resources']
      @instances = resources.map { |resource| Helpers::ServiceInstance.new(id: resource['metadata']['guid']) }
    end

    attr_reader :instances
  end
end