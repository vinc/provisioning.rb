class Dokku
  def initialize(config)
    @config = config
    @servers = []
  end

  def setup(server_address)
    @servers << server_address
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

  def create_app(config)
    name = config["name"]
    @servers.each do |server_address|
      info("Creating dokku app '#{name}' on '#{server_address}'")
      Net::SSH.start(server_address, "root") do |ssh|
        existing_apps = ssh.exec!("dokku apps").to_s.lines.map(&:chomp)
        if existing_apps.include?(name)
          warning("app already existing, skipping")
        else
          exit
          puts ssh.exec!("dokku apps:create #{name}")
          config["services"].each do |service|
            case service
            when "mongo", "postgres", "redis"
              # TODO: install plugins for mongo and redis
              puts ssh.exec!("dokku #{service}:create #{name}-#{service}")
              puts ssh.exec!("dokku #{service}:link #{name}-#{service} #{name}")
            end
          end
          config["domains"].each do |domains|
            puts ssh.exec!("dokku domains:add #{domain}")
          end
        end
      end
    end
  end
end
