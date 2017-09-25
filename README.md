Provisioning.rb
===============

PaaS Provisioning.

Currently limited to dokku apps on AWS or DigitalOcean servers.


Installation
------------

    $ gem install provisioning

Alternatively you can build the gem from its repository:

    $ git clone git://github.com/vinc/provisioning.git
    $ cd provisioning
    $ gem build provisioning.gemspec
    $ gem install provisioning-0.0.1.gem

Usage
-----

Run the provisioning script:

    $ provision manifest.json
    Getting SSH key from authentication agent

    Uploading SSH key to DigitalOcean

    Creating droplet 'dokku.server.net'

    Creating domain 'server.net'
    Configue 'server.net' with the following DNS servers:
      - ns1.digitalocean.com
      - ns2.digitalocean.com
      - ns3.digitalocean.com

    Creating domain record A 'dokku.server.net' to '192.168.13.37'
    Creating domain record CNAME 'example.server.net' to 'dokku.server.net.'
    Configue 'example.com' to point to 'dokku.server.net'
    Configue 'www.example.com' to point to 'dokku.server.net'

    Installing dokku v0.10.4 on '192.168.13.37'
    Run `gem install dokku-cli` to get dokku client on your machine

    Creating dokku app 'example' on '192.168.13.37'

    Adding dokku to git remotes
    Run `git push dokku master` to deploy your code

Provisioning manifest json file:

```json
{
  "manifest": {
    "app": {
      "name": "example",
      "domains": ["example.com", "www.example.com"],
      "services": ["postgres", "redis"]
    },
    "platform": {
      "provider": "dokku",
      "version": "v0.10.4"
    },
    "hosting": {
      "provider": "digitalocean",
      "server": {
        "region": "sfo1",
        "image": "ubuntu-16-04-x64",
        "size": "1gb"
      }
    },
    "dns": {
      "provider": "digitalocean",
      "domain": "sfo1.example.net"
    },
    "ssh": {
      "key": "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC1HxvTzPAMyE9tbbQ7drVYVEnrd1ViKZfOWTwrtGNX1vS7xJvpiNnAaabw0bPAtNV/fK7U/saIKJLkWVVpyf51rYS+YzBM3ZAexGyFqJKpKc9869A1O4Qih+bhTaoEEp7m31HZNY3QFmqxCIS69UE2bsMZgUr+rr+0uQqSkdQDQrBh8wDeFL6WkgkMuWg8ni9UP8JIQPRxkg232WC9r1mZ1KVlxRfesS9iY+Xu3MiGVMbo3mQbN1YzT6TQybG5SryBeRVQZTvwonumJS4ufPH9B1BGxQ1R24jDwFY0j1d5NQp1rr2OGax+EzNI/bUKvWcem/VI5uZ4Bev9IPqbvPbV example@provisioning.sh"
    },
    "providers": {
      "digitalocean": {
        "digitalocean_token": "0000000000000000000000000000000000000000000000000000000000000000"
      }
    }
  }
}
```


License
-------

Copyright (C) 2017 Vincent Ollivier. Released under MIT.
