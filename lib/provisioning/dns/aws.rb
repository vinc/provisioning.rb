require "fog/aws"

require "provisioning"

module Provisioning
  module Dns
    class Aws < Base
      def initialize(config, opts, env)
        @config = config
        @opts = opts
        Fog.mock! if @opts[:mock]
        @client = Fog::DNS.new(
          provider: "aws",
          aws_access_key_id: fetch("AWS_ACCESS_KEY_ID", env: env),
          aws_secret_access_key: fetch("AWS_SECRET_ACCESS_KEY", env: env)
        )
      end

      def create_zone(domain, address)
        Console.info("Creating zone '#{domain}'")

        zone = get_zone(domain)
        if zone
          Console.warning("Domain already exists, skipping")
        else
          zone = @client.zones.create(domain: domain)
        end
      end

      def create_record(domain, type:, name:, data:)
        Console.info("Creating domain record #{type} '#{name}' to '#{data}'")

        zone = get_zone(domain)
        if zone.records.get(name, type)
          Console.warning("Record already exists, skipping")
        else
          zone.records.create(type: type, name: name, value: data)
        end
      end

      def get_name_servers(domain)
        get_zone(domain).reload.nameservers || []
      end

      private

      def get_zone(domain)
        @client.zones.all.find { |z| z.domain == domain + "." }
      end
    end
  end
end
