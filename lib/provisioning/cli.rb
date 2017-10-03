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
      compute = provider("compute")

      compute.upload_ssh_key(@ssh_key)

      i = 1
      server = compute.find_or_create_server(
        name: "#{@platform_provider}#{i}.#{@platform_domain}",
        ssh_key: @ssh_key
      )
      server.wait_for { ready? }
      sleep 5
      @server_address = server.public_ip_address
    end

    def provision_dns
      dns = provider("dns")

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

      # Wilcard subdomains
      dns.create_record(@platform_domain,
        type: "CNAME",
        name: ["*", @platform_domain, ""].join("."),
        data: [@platform_domain, ""].join(".")
      )

      @manifest["app"]["domains"].each do |app_domain|
        Console.success("Configue '#{app_domain}' to point to '#{@platform_domain}'")
      end
    end

    def provision_platform
      platform = provider("platform")

      platform.setup(
        address: @server_address,
        user: @compute_provider == "aws" ? "ubuntu" : "root"
      )
      platform.create_app(@manifest["app"])

      # TODO: add `platform.get_post_install_instructions`
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
            url = "#{@platform_provider}@#{@platform_domain}:#{@app_name}"
            git.add_remote(@platform_provider, url)
          when "flynn"
            url = "https://git.#{@platform_domain}/#{@app_name}.git"
            git.add_remote(@platform_provider, url)
          end
        end
        Console.success("Run `git push #{@platform_provider} master` to deploy your code")
      end
    end

    def self.read_manifest_file(filename)
      Console.info("Reading provisioning manifest file '#{filename}'")
      begin
        json = JSON.parse(File.open(filename).read)
      rescue Errno::ENOENT
        Console.error("Could not read provisioning manifest file '#{filename}'")
      rescue JSON::ParserError
        Console.error("Could not parse provisioning manifest file '#{filename}'")
      end
      json["manifest"]
    end

    private

    def dig_manifest(keys)
      path = []
      hash = @manifest
      keys.each do |key|
        path << key
        hash = hash[key] || Console.error("Could not find #{path.join(".")} in manifest")
      end
      hash
    end

    def set_instance_variable_from_manifest(keys)
      name = "@" + keys.join("_")
      instance_variable_set(name, dig_manifest(keys))
    end

    def provider(type)
      provider = instance_variable_get("@#{type}_provider")

      Console.info("==> Provisioning #{provider} #{type}")

      klass = Provisioning.
        const_get(type.capitalize).
        const_get(provider.capitalize)

      klass.new(@manifest[type], @opts, @env)
    end
  end
end
