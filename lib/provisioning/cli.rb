require "git"
require "json"
require "net/ssh"
require "rainbow"

require "provisioning"

module Provisioning
  module CLI
    def self.get_ssh_key(fingerprint)
      Console.info("Getting SSH key from authentication agent")
      agent = Net::SSH::Authentication::Agent.connect
      agent.identities.find do |identity|
        identity.fingerprint == fingerprint
      end || Console.error("could not get key from the authentication agent, run `ssh-add`")
    end

    def self.start(args, env)
      json_file = args.shift || "manifest.json"

      begin
        json = JSON.parse(File.open(json_file).read)
      rescue Errno::ENOENT, JSON::ParserError
        Console.error("could not read provisioning manifest file '#{json_file}'")
      end

      manifest = json["manifest"]

      ssh_key_fingerprint = manifest["ssh"]["key"]["fingerprint"]

      ssh_key = get_ssh_key(ssh_key_fingerprint)
      puts

      app_name = manifest["app"]["name"]
      domain = manifest["domain"]
      platform = manifest["providers"]["platform"]
      server_hostname = [platform, domain].join(".")
      server_address = nil

      if manifest["providers"]["hosting"] == "digitalocean"
        digitalocean = DigitalOcean.new(manifest["digitalocean"])

        digitalocean.upload_ssh_key(ssh_key)
        puts

        droplet = digitalocean.create_droplet(
          name: server_hostname,
          ssh_key_fingerprint: ssh_key_fingerprint
        )
        server_address = droplet.networks.v4.first.ip_address
        puts
      end

      if manifest["providers"]["dns"] == "digitalocean"
        digitalocean = DigitalOcean.new(manifest["digitalocean"])

        digitalocean.create_domain(domain, server_address)
        Console.success("Configue '#{domain}' with the following DNS servers:")
        digitalocean.get_domain_name_servers(domain).each do |server|
          Console.success("  - #{server}")
        end
        puts

        digitalocean.create_domain_record(
          domain: domain,
          type: "A",
          name: platform,
          data: server_address
        )
        digitalocean.create_domain_record(
          domain: domain,
          type: "CNAME",
          name: app_name,
          data: "#{server_hostname}."
        )
        manifest["app"]["domains"].each do |app_domain|
          Console.success("Configue '#{app_domain}' to point to '#{server_hostname}'")
        end
        puts
      end

      if manifest["providers"]["platform"] == "dokku"
        dokku = Dokku.new(manifest["dokku"])
        dokku.setup(address: server_address, domain: domain)
        Console.success("Run `gem install dokku-cli` to get dokku client on your machine")
        puts

        dokku.create_app(manifest["app"])
        puts

        Console.info("Adding dokku to git remotes")
        begin
          git = Git.open(".")
        rescue ArgumentError
          Console.warning("not a git repository, skipping")
        else
          if git.remotes.map(&:name).include?("dokku")
            Console.warning("remote already exists, skipping")
          else
            git.add_remote("dokku", "dokku@#{server_hostname}:#{app_name}")
          end
          Console.success("Run `git push dokku master` to deploy your code")
        end
      end
    end
  end
end
