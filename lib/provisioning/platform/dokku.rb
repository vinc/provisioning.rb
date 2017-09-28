require "net/ssh"

require "provisioning"

module Provisioning
  module Platform
    class Dokku
      def initialize(config, env)
        @mock = env["MOCK"]
        @config = config
        @servers = []
      end

      def setup(address:, domain:)
        @servers << address
        version = @config["version"]
        Console.info("Installing dokku #{version} on '#{address}'")
        return if @mock
        Net::SSH.start(address, "root") do |ssh|
          if ssh.exec!("which dokku").present?
            Console.warning("Dokku already installed, skipping")
          else
            puts ssh.exec!("wget https://raw.githubusercontent.com/dokku/dokku/#{version}/bootstrap.sh")
            puts ssh.exec!("DOKKU_TAG=#{version} bash bootstrap.sh")
            puts ssh.exec!("service dokku-installer stop")
            puts ssh.exec!("systemctl disable dokku-installer")
            puts ssh.exec!("cat .ssh/authorized_keys | sshcommand acl-add dokku admin")
            puts ssh.exec!("echo -n #{domain} > /home/dokku/VHOST")
            puts ssh.exec!("echo -n #{domain} > /home/dokku/HOSTNAME")
          end
        end
      end

      def create_app(config)
        name = config["name"]
        @servers.each do |address|
          Console.info("Creating dokku app '#{name}' on '#{address}'")
          return if @mock
          Net::SSH.start(address, "root") do |ssh|
            existing_apps = ssh.exec!("dokku apps").to_s.lines.map(&:chomp)
            if existing_apps.include?(name)
              Console.warning("App already exists, skipping")
            else
              puts ssh.exec!("dokku apps:create #{name}")

              config["services"].each do |service|
                #TODO check if service exists
                puts ssh.exec!("dokku plugin:install https://github.com/dokku/dokku-#{service}.git #{service}")
                puts ssh.exec!("dokku #{service}:create #{name}-#{service}")
                puts ssh.exec!("dokku #{service}:link #{name}-#{service} #{name}")
              end

              domains = config["domains"].join(" ")
              puts ssh.exec!("dokku domains:add #{name} #{domains}")
            end
          end
        end
      end
    end
  end
end
