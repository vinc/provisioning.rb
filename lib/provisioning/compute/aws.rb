require "fog/aws"

require "provisioning"

module Provisioning
  module Compute
    class Aws
      KEY_NAME = "provisioning key".freeze

      def initialize(config, opts, env)
        @config = config
        @opts = opts
        Fog.mock! if @opts[:mock]
        @client = Fog::Compute.new(
          provider: "aws",
          region: @config["region"],
          aws_access_key_id: env["AWS_ACCESS_KEY_ID"],
          aws_secret_access_key: env["AWS_SECRET_ACCESS_KEY"]
        )
      end

      def upload_ssh_key(ssh_key)
        Console.info("Uploading SSH key to Amazon Web Services")
        if @client.key_pairs.get(KEY_NAME).nil?
          @client.import_key_pair(KEY_NAME, ssh_key.to_s)
        else
          Console.warning("SSH key already uploaded, skipping")
        end
      end

      def find_or_create_server(name:, ssh_key:)
        Console.info("Creating server '#{name}'")

        @client.servers.all.each do |server|
          if server.ready? && server.tags["name"] == name
            Console.warning("Server already exists, skipping")
            return server
          end
        end

        @client.servers.create(
          image_id: @config["image_id"],
          flavor_id: @config["flavor_id"],
          tags: { name: name },
          key_name: KEY_NAME
        )
      end
    end
  end
end
