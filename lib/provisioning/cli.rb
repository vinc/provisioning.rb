require "git"
require "json"
require "net/ssh"
require "rainbow"

require "provisioning"

module Provisioning
  class CLI
    def initialize(args, env)
      @manifest = self.class.read_manifest_file(args.shift || "manifest.json")
      @env = env

      set_instance_variable_from_manifest(%w[app name])
      set_instance_variable_from_manifest(%w[platform domain])
      set_instance_variable_from_manifest(%w[platform provider])
      set_instance_variable_from_manifest(%w[compute provider])
      set_instance_variable_from_manifest(%w[dns provider])

      @server_address = nil
      @server_hostname = [@platform_provider, @platform_domain].join(".")

      @ssh_key = PublicKey.new(@env["SSH_PUBLIC_KEY"])
    end

    def run
      provision_compute
      provision_dns
      provision_platform
      add_git_remote
    end

    def provision_compute
      config = @manifest["compute"]
      compute = Compute.const_get(@compute_provider.capitalize).new(config, @env)

      compute.upload_ssh_key(@ssh_key)

      server = compute.find_or_create_server(
        name: @server_hostname,
        ssh_key: @ssh_key
      )
      server.wait_for { ready? }
      @server_address = server.public_ip_address
    end

    def provision_dns
      config = @manifest["dns"]
      dns = DNS.const_get(@dns_provider.capitalize).new(config, @env)

      dns.create_domain(@platform_domain, @server_address)
      Console.success("Configue '#{@platform_domain}' with the following DNS servers:")
      dns.get_domain_name_servers(@platform_domain).each do |hostname|
        Console.success("  - #{hostname}")
      end

      dns.create_domain_record(
        domain: @platform_domain,
        type: "A",
        name: @platform_provider,
        data: @server_address
      )

      dns.create_domain_record(
        domain: @platform_domain,
        type: "CNAME",
        name: @app_name,
        data: @server_hostname + "."
      )

      @manifest["app"]["domains"].each do |app_domain|
        Console.success("Configue '#{app_domain}' to point to '#{@server_hostname}'")
      end
    end

    def provision_platform
      config = @manifest["platform"]
      platform = Platform.const_get(@platform_provider.capitalize).new(config, @env)

      platform.setup(address: @server_address, domain: @platform_domain)
      platform.create_app(@manifest["app"])

      case @platform_provider
      when "dokku"
        Console.success("Run `gem install dokku-cli` to get dokku client on your computer")
      end
    end

    def add_git_remote
      Console.info("Adding #{@platform_provider} to git remotes")
      begin
        git = Git.open(".")
      rescue ArgumentError
        Console.warning("Not a git repository, skipping")
      else
        if git.remotes.map(&:name).include?(@platform_provider)
          Console.warning("Remote already exists, skipping")
        else
          case @platform_provider
          when "dokku"
            url = "#{@platform_provider}@#{@server_hostname}:#{@app_name}"
            git.add_remote(@platform_provider, url)
          end
        end
        Console.success("Run `git push dokku master` to deploy your code")
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

    private

    def set_instance_variable_from_manifest(keys)
      name = "@" + keys.join("_")
      instance_variable_set(name, dig_manifest(keys))
    end

    def dig_manifest(keys)
      path = []
      hash = @manifest
      keys.each do |key|
        path << key
        hash = hash[key] || Console.error("Could not find #{path.join(".")} in manifest")
      end
      hash
    end
  end
end
