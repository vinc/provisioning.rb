require "net/ssh"

require "provisioning"

module Provisioning
  module Platform
    class Flynn
      def initialize(config, opts, env)
        @opts = opts
        @config = config
        @servers = []
      end

      def setup(address:, domain:, user: "root")
        @servers << [address, user]
        Console.info("Installing flynn on '#{address}'")
        return if @opts[:mock]
        Net::SSH.start(address, user) do |ssh|
          if ssh_exec(ssh, "which flynn", user: user).present?
            Console.warning("Flynn already installed, skipping")
          else
            [
              "bash < <(curl -fsSL https://dl.flynn.io/install-flynn)",
              "systemctl start flynn-host",
              "CLUSTER_DOMAIN=#{domain} flynn-host bootstrap"
            ].each { |cmd| Console.debug(ssh_exec(ssh, cmd, user: user)) }
          end
        end
      end

      def create_app(config)
        name = config["name"]
        @servers.each do |address, user|
          Console.info("Creating flynn app '#{name}' on '#{address}'")
          return if @opts[:mock]
          Net::SSH.start(address, user) do |ssh|
            out = ssh_exec(ssh, "flynn apps | awk '{ print $2 }'", user: user)
            existing_apps = out.lines.map(&:chomp)
            if existing_apps.include?(name)
              Console.warning("App already exists, skipping")
            else
              cmds = []

              # Configure flynn command
              out = ssh_exec(ssh, "flynn-host cli-add-command", user: user)
              cmds << out.lines.map(&:chomp).find do |line|
                line.start_with?("flynn cluster add")
              end

              cmds << "flynn create #{name}"

              config["services"].each do |service|
                cmds << "flynn -a #{name} resource add #{service}"
              end

              config["domains"].each do |domain|
                cmds << "flynn -a #{name} route add http #{domain}"
              end

              cmds.each { |cmd| Console.debug(ssh_exec(ssh, cmd, user: user)) }
            end
          end
        end
      end

      private

      def ssh_exec(ssh, cmd, user: "root")
        cmd = "sudo bash -c '#{cmd}'" if user != "root"
        ssh.exec!(cmd)
      end
    end
  end
end
