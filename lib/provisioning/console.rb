require "rainbow"

module Provisioning
  module Console
    @verbosity = 3

    def self.debug_mode!
      @verbosity = 4
    end

    def self.silent_mode!
      @verbosity = 0
    end

    def self.debug(text)
      puts text if @verbosity > 3
    end

    def self.info(text)
      puts text if @verbosity > 2
    end

    def self.success(text)
      puts Rainbow("#{text}").green if @verbosity > 1
    end

    def self.warning(text)
      puts Rainbow("Warning: #{text}").yellow if @verbosity > 1
    end

    def self.error(text)
      puts Rainbow("Error: #{text}").red if @verbosity > 0
      exit 1
    end
  end
end
