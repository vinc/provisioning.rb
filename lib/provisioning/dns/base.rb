require "provisioning"

module Provisioning
  module Dns
    class Base
      include Provisioning::Core

      def initialize(config, opts, env)
        raise NotImplementedError
      end

      def create_zone(domain)
        raise NotImplementedError
      end

      def create_record(domain, type:, name:, data:)
        raise NotImplementedError
      end

      def get_name_servers(domain)
        raise NotImplementedError
      end
    end
  end
end
