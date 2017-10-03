require "provisioning"

module Provisioning
  module Compute
    class Base
      include Provisioning::Core

      KEY_NAME = "provisioning key".freeze

      def initialize(config, opts, env)
        raise NotImplementedError
      end

      def upload_ssh_key(ssh_key)
        raise NotImplementedError
      end

      def find_or_create_server(name:, ssh_key:)
        raise NotImplementedError
      end
    end
  end
end
