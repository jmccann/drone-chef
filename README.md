# drone-chef

[![Build Status](http://beta.drone.io/api/badges/jmccann/drone-chef/status.svg)](http://beta.drone.io/jmccann/drone-chef)
[![](https://badge.imagelayers.io/jmccann/drone-chef:latest.svg)](https://imagelayers.io/?images=jmccann/drone-chef:latest 'Get your own badge on imagelayers.io')

Drone plugin to publish cookbooks to Chef Server. For the usage information and a listing of the available options please take a look at [the docs](DOCS.md).

## Execute

Install the deps using `rake`:

```
bundle install --path=gems --retry=5 --jobs=5
```

### Example

```sh
bundle exec bin/drone-chef <<EOF
{
    "repo": {
        "clone_url": "git://github.com/drone/drone",
        "owner": "drone",
        "name": "drone",
        "full_name": "drone/drone"
    },
    "system": {
        "link_url": "https://beta.drone.io"
    },
    "build": {
        "number": 22,
        "status": "success",
        "started_at": 1421029603,
        "finished_at": 1421029813,
        "message": "Update the Readme",
        "author": "johnsmith",
        "author_email": "john.smith@gmail.com",
        "event": "push",
        "branch": "master",
        "commit": "436b7a6e2abaddfd35740527353e78a227ddcb2c",
        "ref": "refs/heads/master"
    },
    "workspace": {
        "root": "/drone/src",
        "path": "/drone/src/github.com/drone/drone"
    },
    "vargs": {
        "user": "octocat",
        "key": "-----BEGIN RSA PRIVATE KEY-----\nMIIasdf...\n-----END RSA PRIVATE KEY-----",
        "server": "https://chefserver.com",
        "org": "my_org",
        "freeze": true,
        "ssl_verify": false
    }
}
EOF
```

## Docker

Build the container using `rake`:

```
bundle install --path=gems --retry=5 --jobs=5
bin/rake build docker
```

### Example

```sh
docker run -i plugins/drone-chef:latest <<EOF
{
    "repo": {
        "clone_url": "git://github.com/drone/drone",
        "owner": "drone",
        "name": "drone",
        "full_name": "drone/drone"
    },
    "system": {
        "link_url": "https://beta.drone.io"
    },
    "build": {
        "number": 22,
        "status": "success",
        "started_at": 1421029603,
        "finished_at": 1421029813,
        "message": "Update the Readme",
        "author": "johnsmith",
        "author_email": "john.smith@gmail.com",
        "event": "push",
        "branch": "master",
        "commit": "436b7a6e2abaddfd35740527353e78a227ddcb2c",
        "ref": "refs/heads/master"
    },
    "workspace": {
        "root": "/drone/src",
        "path": "/drone/src/github.com/drone/drone"
    },
    "vargs": {
        "user": "octocat",
        "key": "-----BEGIN RSA PRIVATE KEY-----\nMIIasdf...\n-----END RSA PRIVATE KEY-----",
        "server": "https://chefserver.com",
        "org": "my_org",
        "freeze": true,
        "ssl_verify": false
    }
}
EOF
```
