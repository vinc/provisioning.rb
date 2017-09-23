class Dokku
  def initialize(config)
    @config = config
  end

  def install(server_address)
    version = @config["version"]
    info("Installing dokku #{version} on '#{server_address}'")
    Net::SSH.start(server_address, "root") do |ssh|
      if ssh.exec!("which dokku").present?
        warning("dokku already installed, skipping")
      else
        exit
        puts ssh.exec!("wget https://raw.githubusercontent.com/dokku/dokku/#{version}/bootstrap.sh")
        puts ssh.exec!("sudo DOKKU_TAG=#{version} bash bootstrap.sh")
      end
    end
  end
end
