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

      def setup(address:, domain:)
        @servers << address
        version = @config["version"]
        Console.info("Installing dokku #{version} on '#{address}'")
        return if @opts[:mock]
        Net::SSH.start(address, "root") do |ssh|
          if ssh.exec!("which dokku").present?
            Console.warning("Dokku already installed, skipping")
          else
            [
              "wget https://raw.githubusercontent.com/dokku/dokku/#{version}/bootstrap.sh",
              "DOKKU_TAG=#{version} bash bootstrap.sh",
              "service dokku-installer stop",
              "systemctl disable dokku-installer",
              "cat .ssh/authorized_keys | sshcommand acl-add dokku admin",
              "echo -n #{domain} > /home/dokku/VHOST",
              "echo -n #{domain} > /home/dokku/HOSTNAME"
            ].each { |command| Console.debug(ssh.exec!(command)) }
          end
        end
      end

      def create_app(config)
        name = config["name"]
        @servers.each do |address|
          Console.info("Creating dokku app '#{name}' on '#{address}'")
          return if @opts[:mock]
          Net::SSH.start(address, "root") do |ssh|
            existing_apps = ssh.exec!("dokku apps").to_s.lines.map(&:chomp)
            if existing_apps.include?(name)
              Console.warning("App already exists, skipping")
            else
              Console.debug(ssh.exec!("dokku apps:create #{name}"))

              config["services"].each do |service|
                #TODO check if service exists
                [
                  "dokku plugin:install https://github.com/dokku/dokku-#{service}.git #{service}",
                  "dokku #{service}:create #{name}-#{service}",
                  "dokku #{service}:link #{name}-#{service} #{name}"
                ].each { |command| Console.debug(ssh.exec!(command)) }
              end

              domains = config["domains"].join(" ")
              Console.debug(ssh.exec!("dokku domains:add #{name} #{domains}"))
            end
          end
        end
      end
    end
  end
end
