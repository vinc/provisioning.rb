require "git"
require "json"
require "net/ssh"
require "rainbow"
require "trollop"

require "provisioning"

module Provisioning
  class CLI
    def initialize(args, env)
      @opts = parse_opts(args)
      @env = env

      if @opts[:silent]
        Console.silent_mode!
      elsif @opts[:verbose]
        Console.debug_mode!
      end

      @manifest = self.class.read_manifest_file(args.shift || "manifest.json")

      set_instance_variable_from_manifest(%w[app name])
      set_instance_variable_from_manifest(%w[platform domain])
      set_instance_variable_from_manifest(%w[platform provider])
      set_instance_variable_from_manifest(%w[compute provider])
      set_instance_variable_from_manifest(%w[dns provider])

      @server_address = nil
      @server_hostname = [@platform_provider, @platform_domain].join(".")

      key_path = File.join(@env["HOME"], ".ssh/id_rsa.pub")
      key_body = @env["SSH_PUBLIC_KEY"] || File.open(key_path).read
      @ssh_key = PublicKey.new(key_body)
    end

    def parse_opts(args)
      Trollop::options(args) do
        version "Provisioning v#{Provisioning::VERSION}"
        opt :silent,  "Use silent mode"
        opt :verbose, "Use verbose mode"
        opt :mock,    "Use mock mode"
        opt :help,    "Show this message"
        opt :version, "Print version and exit", short: "V"
      end
    end

    def run
      provision_compute
      provision_dns
      provision_platform
      add_git_remote
    end

    def provision_compute
      klass = Compute.const_get(@compute_provider.capitalize)
      compute = klass.new(@manifest["compute"], @opts, @env)

      compute.upload_ssh_key(@ssh_key)

      server = compute.find_or_create_server(
        name: @server_hostname,
        ssh_key: @ssh_key
      )
      server.wait_for { ready? }
      sleep 5
      @server_address = server.public_ip_address
    end

    def provision_dns
      klass = DNS.const_get(@dns_provider.capitalize)
      dns = klass.new(@manifest["dns"], @opts, @env)

      dns.create_zone(@platform_domain, @server_address)
      Console.success("Configue '#{@platform_domain}' with the following DNS servers:")
      dns.get_name_servers(@platform_domain).each do |hostname|
        Console.success("  - #{hostname}")
      end

      dns.create_record(@platform_domain,
        type: "A",
        name: [@platform_domain, ""].join("."),
        data: @server_address
      )

      dns.create_record(@platform_domain,
        type: "A",
        name: [@platform_provider, @platform_domain, ""].join("."),
        data: @server_address
      )

      dns.create_record(@platform_domain,
        type: "CNAME",
        name: [@app_name, @platform_domain, ""].join("."),
        data: [@server_hostname, ""].join(".")
      )

      @manifest["app"]["domains"].each do |app_domain|
        Console.success("Configue '#{app_domain}' to point to '#{@server_hostname}'")
      end
    end

    def provision_platform
      klass = Platform.const_get(@platform_provider.capitalize)
      platform = klass.new(@manifest["platform"], @opts, @env)

      platform.setup(
        address: @server_address,
        domain: @platform_domain,
        user: @compute_provider == "aws" ? "ubuntu" : "root"
      )
      platform.create_app(@manifest["app"])

      case @platform_provider
      when "dokku"
        Console.success("Run `gem install dokku-cli` to get dokku client on your computer")
      end
    end

    def add_git_remote
      Console.info("Adding #{@platform_provider} to git remotes")
      return if @opts[:mock]
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
