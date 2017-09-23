require "net/ssh"

require "provisioning"

module Provisioning
  class Dokku
    def initialize(config)
      @config = config
      @servers = []
    end

    def setup(server_address)
      @servers << server_address
      version = @config["version"]
      Console.info("Installing dokku #{version} on '#{server_address}'")
      Net::SSH.start(server_address, "root") do |ssh|
        if ssh.exec!("which dokku").present?
          Console.warning("dokku already installed, skipping")
        else
          puts ssh.exec!("wget https://raw.githubusercontent.com/dokku/dokku/#{version}/bootstrap.sh")
          puts ssh.exec!("sudo DOKKU_TAG=#{version} bash bootstrap.sh")
        end
      end
    end

    def create_app(config)
      name = config["name"]
      @servers.each do |server_address|
        Console.info("Creating dokku app '#{name}' on '#{server_address}'")
        Net::SSH.start(server_address, "root") do |ssh|
          existing_apps = ssh.exec!("dokku apps").to_s.lines.map(&:chomp)
          if existing_apps.include?(name)
            Console.warning("app already exists, skipping")
          else
            puts ssh.exec!("dokku apps:create #{name}")

            config["services"].each do |service|
              case service
              when "mongo", "postgres", "redis"
                puts ssh.exec!("dokku plugin:install https://github.com/dokku/dokku-#{service}.git #{service}")
                puts ssh.exec!("dokku #{service}:create #{name}-#{service}")
                puts ssh.exec!("dokku #{service}:link #{name}-#{service} #{name}")
              end
            end

            domains = config["domains"].join(" ")
            puts ssh.exec!("dokku domains:add #{name} #{domains}")
          end
        end
      end
    end
  end
end
