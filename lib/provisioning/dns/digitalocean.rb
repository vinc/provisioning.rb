require "droplet_kit"

require "provisioning"

module Provisioning
  module DNS
    class Digitalocean
      def initialize(config, opts, env)
        @config = config
        @opts = opts
        @client = DropletKit::Client.new(
          access_token: env["DIGITALOCEAN_TOKEN"]
        ) unless @opts[:mock]
      end

      def create_domain(name, address)
        Console.info("Creating domain '#{name}'")

        disable_verbose
        return if @opts[:mock]
        if @client.domains.all.map(&:name).include?(name)
          Console.warning("Domain already exists, skipping")
        else
          domain = DropletKit::Domain.new(name: name, ip_address: address)
          @client.domains.create(domain)
        end
      ensure
        restore_verbose
      end

      def create_domain_record(domain:, type:, name:, data:)
        Console.info("Creating domain record #{type} '#{name}.#{domain}' to '#{data}'")

        disable_verbose
        return if @opts[:mock]
        if @client.domain_records.all(for_domain: domain).map(&:name).include?(name)
          Console.warning("Record already exists, skipping")
        else
          record = DropletKit::DomainRecord.new(type: type, name: name, data: data)
          @client.domain_records.create(record, for_domain: domain)
        end
      ensure
        restore_verbose
      end

      def get_domain_name_servers(domain)
        disable_verbose
        return %w[ns1.example.net ns2.example.net] if @opts[:mock]
        @client.domain_records.all(for_domain: domain).
          select { |r| r.type == "NS" }.
          map(&:data)
      ensure
        restore_verbose
      end

      private

      def disable_verbose
        $OLD_VERBOSE = $VERBOSE
        $VERBOSE = nil
      end

      def restore_verbose
        $VERBOSE = $OLD_VERBOSE
      end
    end
  end
end
