require "rainbow"

module Provisioning
  module Console
    def self.info(text)
      puts text
    end

    def self.success(text)
      puts Rainbow("#{text}").green
    end

    def self.warning(text)
      puts Rainbow("Warning: #{text}").yellow
    end

    def self.error(text)
      puts Rainbow("Error: #{text}").red
      exit 1
    end
  end
end
