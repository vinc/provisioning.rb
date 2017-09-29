require "net/ssh"

require "provisioning"

module Provisioning
  module Platform
    class Dokku
      def initialize(config, opts, env)
        @opts = opts
        @config = config
        @servers = []
      end

      def setup(address:, domain:, user: "root")
        @servers << [address, user]
        version = @config["version"]
        Console.info("Installing dokku #{version} on '#{address}'")
        return if @opts[:mock]
        Net::SSH.start(address, user) do |ssh|
          if ssh_exec(ssh, "which dokku", user: user).present?
            Console.warning("Dokku already installed, skipping")
          else
            # TODO: configure hostname
            [
              "wget https://raw.githubusercontent.com/dokku/dokku/#{version}/bootstrap.sh",
              "DOKKU_TAG=#{version} bash bootstrap.sh",
              "service dokku-installer stop",
              "systemctl disable dokku-installer",
              "cat .ssh/authorized_keys | sshcommand acl-add dokku admin",
              "echo -n #{domain} > /home/dokku/VHOST",
              "echo -n #{domain} > /home/dokku/HOSTNAME"
            ].each { |cmd| Console.debug(ssh_exec(ssh, cmd, user: user)) }
          end
        end
      end

      def create_app(config)
        name = config["name"]
        @servers.each do |address, user|
          Console.info("Creating dokku app '#{name}' on '#{address}'")
          return if @opts[:mock]
          Net::SSH.start(address, user) do |ssh|
            existing_apps = ssh_exec(ssh, "dokku apps", user: user).to_s.lines.map(&:chomp)
            if existing_apps.include?(name)
              Console.warning("App already exists, skipping")
            else
              Console.debug(ssh_exec(ssh, "dokku apps:create #{name}", user: user))

              config["services"].each do |service|
                # TODO: check if service exists
                [
                  "dokku plugin:install https://github.com/dokku/dokku-#{service}.git #{service}",
                  "dokku #{service}:create #{name}-#{service}",
                  "dokku #{service}:link #{name}-#{service} #{name}"
                ].each { |cmd| Console.debug(ssh_exec(ssh, cmd, user: user)) }
              end

              domains = config["domains"].join(" ")
              Console.debug(ssh_exec(ssh, "dokku domains:add #{name} #{domains}", user: user))
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
