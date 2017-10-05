require "net/ssh"

require "provisioning"

module Provisioning
  module Platform
    class Dokku < Base
      def setup(address:, user: "root")
        @servers << [address, user]
        version = fetch("version", config: @config)
        Console.info("Installing dokku #{version} on '#{address}'")
        return if @opts[:mock]
        Net::SSH.start(address, user) do |ssh|
          if ssh_exec(ssh, "which dokku", user: user).present?
            Console.warning("Dokku already installed, skipping")
          else
            # TODO: configure hostname
            domain = fetch("domain", config: @config)
            [
              "wget https://raw.githubusercontent.com/dokku/dokku/#{version}/bootstrap.sh",
              "DOKKU_TAG=#{version} bash bootstrap.sh",
              "service dokku-installer stop",
              "systemctl disable dokku-installer",
              "cat .ssh/authorized_keys | sshcommand acl-add dokku admin",
              "echo #{domain} > /home/dokku/VHOST",
              "echo #{domain} > /home/dokku/HOSTNAME"
            ].each { |cmd| Console.debug(ssh_exec(ssh, cmd, user: user)) }
          end
        end
      end

      def create_app(config)
        name = fetch("name", config: config)
        @servers.each do |address, user|
          Console.info("Creating dokku app '#{name}' on '#{address}'")
          next if @opts[:mock]
          Net::SSH.start(address, user) do |ssh|
            existing_apps = ssh_exec(ssh, "dokku apps", user: user).to_s.lines.map(&:chomp)
            if existing_apps.include?(name)
              Console.warning("App already exists, skipping")
            else
              Console.debug(ssh_exec(ssh, "dokku apps:create #{name}", user: user))

              fetch("services", [], config: config).each do |service|
                if @servers.count > 1
                  Console.warning("Service '#{service}' for dokku wont work in a cluster configuration")
                end
                # TODO: check if service exists
                [
                  "dokku plugin:install https://github.com/dokku/dokku-#{service}.git #{service}",
                  "dokku #{service}:create #{name}-#{service}",
                  "dokku #{service}:link #{name}-#{service} #{name}"
                ].each { |cmd| Console.debug(ssh_exec(ssh, cmd, user: user)) }
              end

              fetch("domains", [], config: config).each do |domain|
                # This will replace default subdomain 'foo.example.com' in /dokku/foo/VHOST
                # because the app has not been deployed once yet.
                Console.debug(ssh_exec(ssh, "dokku domains:add #{name} #{domain}", user: user))
              end
            end
          end
        end
      end
    end
  end
end
