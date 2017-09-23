require "droplet_kit"

require "provisioning"

module Provisioning
  class DigitalOcean
    def initialize(config)
      @config = config
      @client = DropletKit::Client.new(access_token: @config["token"])
    end

    def upload_ssh_key(ssh_key)
      Console.info("Uploading SSH key to DigitalOcean")

      disable_verbose
      if @client.ssh_keys.all.map(&:fingerprint).include?(ssh_key.fingerprint)
        Console.warning("SSH key already uploaded to DigitalOcean, skipping")
      else
        key = DropletKit::SSHKey.new(
          name: "provisioning key",
          public_key: ssh_key.to_s
        )
        @client.ssh_keys.create(key)
      end
      restore_verbose
    end

    def create_droplet(name:, ssh_key_fingerprint:)
      Console.info("Creating droplet '#{name}'")

      disable_verbose
      @client.droplets.all.each do |droplet|
        if droplet.name == name
          Console.warning("droplet already exists, skipping")
          return droplet
        end
      end

      droplet = DropletKit::Droplet.new(
        name: name,
        region: @config["droplet"]["region"],
        image: @config["droplet"]["image"],
        size: @config["droplet"]["size"],
        ssh_keys: [ssh_key_fingerprint]
      )
      @client.droplets.create(droplet)
      droplet
    ensure
      restore_verbose
    end

    def create_domain(name, address)
      Console.info("Creating domain '#{name}'")

      disable_verbose
      if @client.domains.all.map(&:name).include?(name)
        Console.warning("domain already exists, skipping")
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
      if @client.domain_records.all(for_domain: domain).map(&:name).include?(name)
        Console.warning("record already exists, skipping")
      else
        record = DropletKit::DomainRecord.new(type: type, name: name, data: data)
        @client.domain_records.create(record, for_domain: domain)
      end
    ensure
      restore_verbose
    end

    def get_domain_name_servers(domain)
      disable_verbose
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
