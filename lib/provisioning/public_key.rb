module Provisioning
  class PublicKey
    def initialize(key)
      unless key.start_with?("ssh-rsa ")
        raise ArgumentError.new("Wrong SSH RSA public key format")
      end
      @key = key
    end

    def fingerprint
      bin = Base64.decode64(@key.split[1])
      md5 = OpenSSL::Digest::MD5.new(bin)
      md5.to_s.scan(/../).join(":")
    end

    def to_s
      @key
    end
  end
end

