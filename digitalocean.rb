class DigitalOcean
  def initialize(config)
    @config = config
    @client = DropletKit::Client.new(access_token: @config["token"])
  end

  def upload_ssh_key(ssh_key)
    info("Uploading SSH key to DigitalOcean")

    disable_verbose
    if @client.ssh_keys.all.map(&:fingerprint).include?(ssh_key.fingerprint)
      warning("SSH key already uploaded to DigitalOcean, skipping")
    else
      key = DropletKit::SSHKey.new(
        name: "provisioning key",
        public_key: ssh_key.to_s
      )
      exit
      @client.ssh_keys.create(key)
    end
    restore_verbose
  end

  def create_droplet(name:, ssh_key_fingerprint:)
    info("Creating droplet '#{name}'")

    disable_verbose
    @client.droplets.all.each do |droplet|
      if droplet.name == name
        warning("droplet already exists, skipping")
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

    exit
    client.droplets.create(droplet)
    droplet
  ensure
    restore_verbose
  end
end
