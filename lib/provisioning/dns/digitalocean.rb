require "droplet_kit"

require "provisioning"

module Provisioning
  module Dns
    class Digitalocean < Base
      def initialize(config, opts, env)
        @config = config
        @opts = opts
        @client = DropletKit::Client.new(
          access_token: fetch("DIGITALOCEAN_TOKEN", env: env)
        ) unless @opts[:mock]
      end

      def create_zone(name, address)
        Console.info("Creating zone '#{name}'")

        disable_verbose
        return if @opts[:mock]
        if @client.domains.all.map(&:name).include?(name)
          Console.warning("Domain already exists, skipping")
        else
          Console.info("Creating domain record A '@' to '#{address}'")
          domain = DropletKit::Domain.new(name: name, ip_address: address)
          @client.domains.create(domain)
        end
      ensure
        restore_verbose
      end

      def create_record(domain, type:, name:, value:)
        name = name.gsub("#{domain}.", "@").gsub(".@", "")
        value = value.is_a?(Array) ? value : [value]
        value_to_s = value.join(", ")
        Console.info("Creating domain record #{type} '#{name}' to '#{value_to_s}'")

        disable_verbose
        return if @opts[:mock]

        records = @client.domain_records.all(for_domain: domain)
        value.each do |data|
          if records.any? { |r| r.name == name && r.data == data }
            Console.warning("Record already exists, skipping")
          else
            record = DropletKit::DomainRecord.new(type: type, name: name, data: data)
            @client.domain_records.create(record, for_domain: domain)
          end
        end
      ensure
        restore_verbose
      end

      def get_name_servers(domain)
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
