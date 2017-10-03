require "provisioning"

module Provisioning
  module Platform
    class Base
      include Provisioning::Core

      def initialize(config, opts, env)
        @opts = opts
        @config = config
        @servers = []
      end

      def setup(address:, user: "root")
        @servers << [address, user]
        raise NotImplementedError
      end

      def create_app(config)
        raise NotImplementedError
      end

      protected

      def ssh_exec(ssh, cmd, user: "root")
        cmd = "sudo bash -c '#{cmd}'" if user != "root"
        ssh.exec!(cmd)
      end
    end
  end
end
