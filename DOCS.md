Use the chef plugin to deploy cookbooks to a Chef server.
The following parameters are used to configuration this plugin:

* **user** - connects as this user
* **key** - connects with this private key
* **server** - Chef server to connect to
* **org** - Chef org to use on the Chef server
* **freeze** - Wether or not to freeze the version

The following is a sample Docker configuration in your .drone.yml file:

```yaml
deploy:
  chef:
    user: userid
    key: "-----BEGIN RSA PRIVATE KEY-----\nMIIasdf...\n-----END RSA PRIVATE KEY-----"
    server: https://chefserver.com
    org: my_org
    freeze: true
```
