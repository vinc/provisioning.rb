require "provisioning"

module Provisioning
  module Core
    def fetch(key, default = nil, env: nil, config: nil)
      if env
        env[key] || default || Console.error("Could not find '#{key}' in environment")
      elsif config
        config[key] || default || Console.error("Could not find '#{key}' in manifest")
      else
        # TODO: env or config required
      end
    end
  end
end
