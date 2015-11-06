Use the chef plugin to deploy cookbooks to a Chef server.

Global Parameters
=================
The following are global parameters used for configuration this plugin:
* **user** - connects as this user
* **key** - connects with this private key
* **server** - Chef server to connect to
* **type** - (default: `'supermarket'`) Type of server to upload to. Valid values: `'supermarket'`, `'server'`
* **ssl_verify_mode** - (default: `true`) Enable/Disable SSL verify

Chef Server Specific Parameters
===============================
The following are parameters used for configuration this plugin when uploading to a Chef Server:
* **org** - Chef org to use on the Chef server
* **freeze** - (default: `true`) Wether or not to freeze the version
* **recursive** - (default: `true`) Enable/Disable ability to upload all dependency cookbooks as well

Example
=======

### Minimal Definition
This will upload the cookbook to a supermarket server
```yaml
deploy:
  chef:
    image: jmccann/drone-chef
    user: userid
    key: "-----BEGIN RSA PRIVATE KEY-----\nMIIasdf...\n-----END RSA PRIVATE KEY-----"
    server: https://mysupermarket.com
```

### Chef Server Definition
```yaml
deploy:
  chef:
    image: jmccann/drone-chef
    user: userid
    key: "-----BEGIN RSA PRIVATE KEY-----\nMIIasdf...\n-----END RSA PRIVATE KEY-----"
    server: https://chefserver.com
    type: server
    org: my_org
    freeze: true
    ssl_verify_mode: false
```
