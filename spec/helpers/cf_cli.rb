# frozen_string_literal: true

module Helpers
  module Environment
    class CFCLI
      def initialize
        cf_target
        cf_login
      end

      def cf_curl(command)
        `cf curl #{command}`
      end

      def service_instances
        cf_curl('/v2/service_instances')
      end

      def cf_api
        ENV['CF_API'] || 'https://api.bosh-lite.com'
      end

      def cf_username
        ENV['CF_USERNAME'] || 'admin'
      end

      def cf_password
        ENV['CF_PASSWORD'] || 'admin'
      end

      def cf_target
        `cf api --skip-ssl-validation #{cf_api}`
      end

      def cf_login
        `cf auth #{cf_username} #{cf_password}`
      end

      def cf_auth_token
        `cf oauth-token | tail -n 1`.strip!
      end
    end
  end
end