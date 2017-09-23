Gem::Specification.new do |s|
  s.name        = "provisioning"
  s.version     = "0.0.1"
  s.date        = "2017-09-23"
  s.license     = "MIT"
  s.summary     = "PaaS Provisioning"
  s.description = s.summary
  s.homepage    = "https://github.com/vinc/provisioning.rb"
  s.email       = "v@vinc.cc"
  s.authors     = [
    "Vincent Ollivier"
  ]
  s.files       = [
    "lib/provisioning.rb",
    "lib/provisioning/cli.rb",
    "lib/provisioning/console.rb",
    "lib/provisioning/digitalocean.rb",
    "lib/provisioning/dokku.rb",
  ]
  s.executables << "provision"
  s.add_runtime_dependency("git",         "~> 1.3", ">= 1.3.0")
  s.add_runtime_dependency("rainbow",     "~> 2.2", ">= 2.2.0")
  s.add_runtime_dependency("droplet_kit", "~> 2.1", ">= 2.1.0")
  s.add_runtime_dependency("net-ssh",     "~> 4.1", ">= 4.1.0")
end
