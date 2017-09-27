require "fog/digitalocean"

require "provisioning"

module Provisioning
  module Hosting
    class Digitalocean
      KEY_NAME = "provisioning key".freeze

      def initialize(config)
        @config = config
        @client = Fog::Compute.new(
          provider: :digitalocean,
          digitalocean_token: ENV["DIGITALOCEAN_TOKEN"]
        )
      end

      def upload_ssh_key(ssh_key)
        Console.info("Uploading SSH key to DigitalOcean")
        if @client.ssh_keys.all.map(&:fingerprint).include?(ssh_key.fingerprint)
          Console.warning("SSH key already uploaded, skipping")
        else
          @client.ssh_keys.create(
            name: KEY_NAME,
            ssh_pub_key: ssh_key.to_s
          )
        end
      end

      def find_or_create_server(name:, ssh_key:)
        Console.info("Creating server '#{name}'")

        @client.servers.all.each do |server|
          if server.name == name
            Console.warning("Server already exists, skipping")
            return server
          end
        end

        @client.servers.create(
          name: name,
          region: @config["server"]["region"],
          image: @config["server"]["image"],
          size: @config["server"]["size"],
          ssh_keys: [ssh_key.fingerprint]
        )
      end
    end
  end
end
