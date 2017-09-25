Provisioning.rb
===============

PaaS Provisioning.

Currently limited to dokku apps on digital ocean servers.


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
      "key": {
        "fingerprint": "00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00"
      }
    },
    "providers": {
      "digitalocean": {
        "token": "0000000000000000000000000000000000000000000000000000000000000000"
      }
    }
  }
}
```


License
-------

Copyright (C) 2017 Vincent Ollivier. Released under MIT.
