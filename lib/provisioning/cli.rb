require "git"
require "json"
require "net/ssh"
require "rainbow"

require "provisioning"

module Provisioning
  module CLI
    def self.start(args, env)
      manifest = read_manifest_file(args.shift || "manifest.json")

      ssh_key = get_ssh_key(manifest["ssh"]["key"]["fingerprint"])

      app_name = manifest["app"]["name"]
      domain = manifest["dns"]["domain"]
      platform_provider = manifest["platform"]["provider"]
      server_hostname = [platform_provider, domain].join(".")
      server_address = nil

      if manifest["hosting"]["provider"] == "digitalocean"
        config = manifest["hosting"].merge(manifest["providers"]["digitalocean"])
        hosting = Hosting::DigitalOcean.new(config)

        hosting.upload_ssh_key(ssh_key)

        server = hosting.find_or_create_server(
          name: server_hostname,
          ssh_key: ssh_key
        )
        server.wait_for { ready? }
        server_address = server.public_ip_address
      end

      if manifest["dns"]["provider"] == "digitalocean"
        config = manifest["dns"].merge(manifest["providers"]["digitalocean"])
        dns = DNS::DigitalOcean.new(config)

        dns.create_domain(domain, server_address)
        Console.success("Configue '#{domain}' with the following DNS servers:")
        dns.get_domain_name_servers(domain).each do |hostname|
          Console.success("  - #{hostname}")
        end

        dns.create_domain_record(
          domain: domain,
          type: "A",
          name: platform_provider,
          data: server_address
        )
        dns.create_domain_record(
          domain: domain,
          type: "CNAME",
          name: app_name,
          data: "#{server_hostname}."
        )
        manifest["app"]["domains"].each do |app_domain|
          Console.success("Configue '#{app_domain}' to point to '#{server_hostname}'")
        end
      end

      if manifest["platform"]["provider"] == "dokku"
        dokku = Platform::Dokku.new(manifest["platform"])
        dokku.setup(address: server_address, domain: domain)
        Console.success("Run `gem install dokku-cli` to get dokku client on your machine")

        dokku.create_app(manifest["app"])

        Console.info("Adding dokku to git remotes")
        begin
          git = Git.open(".")
        rescue ArgumentError
          Console.warning("Not a git repository, skipping")
        else
          if git.remotes.map(&:name).include?("dokku")
            Console.warning("Remote already exists, skipping")
          else
            git.add_remote("dokku", "dokku@#{server_hostname}:#{app_name}")
          end
          Console.success("Run `git push dokku master` to deploy your code")
        end
      end
    end

    def self.read_manifest_file(filename)
      Console.info("Reading provisioning manifest file '#{filename}'")
      begin
        json = JSON.parse(File.open(filename).read)
      rescue Errno::ENOENT, JSON::ParserError
        Console.error("Could not read provisioning manifest file '#{filename}'")
      end
      json["manifest"]
    end

    def self.get_ssh_key(fingerprint)
      Console.info("Getting SSH key from authentication agent")
      agent = Net::SSH::Authentication::Agent.connect
      agent.identities.find do |identity|
        identity.fingerprint == fingerprint
      end || Console.error("Could not get key from the authentication agent, run `ssh-add`")
    end
  end
end
