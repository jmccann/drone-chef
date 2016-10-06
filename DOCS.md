Global Parameters
=================
The following are global parameters used for configuration this plugin:
* **user** - connects as this user
* **server** - Chef server to connect to
* **berks_files** - (default: `['Berksfile']`) List of Berksfiles to use
* **ssl_verify** - (default: `true`) Enable/Disable SSL verify
* **org** - Chef org to use on the Chef server
* **freeze** - (default: `true`) Wether or not to freeze the version
* **recursive** - (default: `true`) Enable/Disable ability to upload all dependency cookbooks as well

### Secrets
The following secret values can be set to configure the plugin.

* **CHEF_PRIVATE_KEY** - The private key of the **user** to authenticate with

It is highly recommended to put the **CHEF_PRIVATE_KEY** into secrets so it is not exposed to users. This can be done using the [drone-cli](http://readme.drone.io/0.5/reference/cli/overview/).

```
drone secret add --image=jmccann/drone-chef:0.5 \
  octocat/hello-world CHEF_PRIVATE_KEY @/path/to/keyfile
```

Then sign and commit the YAML file after all secrets are added.

```
drone sign octocat/hello-world
```

See [secrets](http://readme.drone.io/0.5/usage/secrets/) for additional information on secrets.

Example
=======
### Minimal Chef Server Definition
```yaml
deploy:
  chef:
    image: jmccann/drone-chef:0.5
    user: userid
    server: https://chefserver.com
    org: my_org
```
