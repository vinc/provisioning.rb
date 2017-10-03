require "net/ssh"

require "provisioning"

module Provisioning
  module Platform
    class Flynn < Base
      def setup(address:, user: "root")
        Console.info("Installing flynn on '#{address}'")
        @servers << [address, user]
        return if @opts[:mock]
        Net::SSH.start(address, user) do |ssh|
          if ssh_exec(ssh, "which flynn", user: user).present?
            Console.warning("Flynn already installed, skipping")
          else
            [
              "bash < <(curl -fsSL https://dl.flynn.io/install-flynn)",
              "systemctl start flynn-host",
            ].each { |cmd| Console.debug(ssh_exec(ssh, cmd, user: user)) }

            if @servers.count == 1
              @token = ssh_exec(ssh, "flynn-host init --init-discovery", user: user)
            else
              ssh_exec(ssh, "flynn-host init --discovery #{@token}", user: user)
            end
          end
        end
      end

      def create_app(config)
        name = fetch("name", config: config)
        (address, user) = @servers.first

        Console.info("Creating flynn app '#{name}' on '#{address}'")
        return if @opts[:mock]
        Net::SSH.start(address, user) do |ssh|
          out = ssh_exec(ssh, "flynn apps | awk '{ print $2 }'", user: user)
          existing_apps = out.lines.map(&:chomp)
          if existing_apps.include?(name)
            Console.warning("App already exists, skipping")
          else
            cmds = []

            # Bootstrap flynn
            platform_domain = fetch("domain", config: @config)
            bootstrap = "CLUSTER_DOMAIN=#{platform_domain} flynn-host bootstrap"
            bootstrap += " --min-hosts 3 --discovery #{@token}" if @token && @servers.count >= 3
            cmds << bootstrap

            # Configure flynn command
            out = ssh_exec(ssh, "flynn-host cli-add-command", user: user)
            cmds << out.lines.map(&:chomp).find do |line|
              line.start_with?("flynn cluster add")
            end

            cmds << "flynn create #{name}"

            fetch("services", [], config: config).each do |service|
              cmds << "flynn -a #{name} resource add #{service}"
            end

            fetch("domains", [], config: config).each do |domain|
              cmds << "flynn -a #{name} route add http #{domain}"
            end

            cmds.each { |cmd| Console.debug(ssh_exec(ssh, cmd, user: user)) }
          end
        end
      end
    end
  end
end
