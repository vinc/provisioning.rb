RSpec.describe Provisioning::CLI do
  it "executes a provisioning manifest" do
    args = ["manifest.sample.json", "--mock"]
    env = {
      "DIGITALOCEAN_TOKEN" => "xxxxxx",
      "HOME" => ENV["HOME"]
    }
    Provisioning::CLI.new(args, env).run
  end
end
