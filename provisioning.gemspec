lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "provisioning/version"

Gem::Specification.new do |s|
  s.name        = "provisioning"
  s.version     = Provisioning::VERSION
  s.license     = "MIT"
  s.summary     = "Open PaaS provisioning"
  s.description = "Open PaaS provisioning on cloud providers from JSON manifest file"
  s.homepage    = "https://github.com/vinc/provisioning.rb"
  s.email       = "v@vinc.cc"
  s.authors     = ["Vincent Ollivier"]
  s.files       = Dir.glob("{bin,lib}/**/*") + %w[LICENSE README.md]
  s.executables = %w[provision]
  s.add_runtime_dependency("droplet_kit",      "~> 2.1", ">= 2.1.0")
  s.add_runtime_dependency("fog-aws",          "~> 1.4", ">= 1.4.0")
  s.add_runtime_dependency("fog-digitalocean", "~> 0.3", ">= 0.3.0")
  s.add_runtime_dependency("git",              "~> 1.3", ">= 1.3.0")
  s.add_runtime_dependency("net-ssh",          "~> 4.1", ">= 4.1.0")
  s.add_runtime_dependency("rainbow",          "~> 2.2", ">= 2.2.0")
  s.add_runtime_dependency("trollop",          "~> 2.1", ">= 2.1.0")
end
