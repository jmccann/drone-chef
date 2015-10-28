# Docker image for the rsync plugin
#
#     docker build --rm=true -t jmccann/drone-chef .

FROM jmccann/drone-chefdk

ADD . /opt/drone-chef/

ENTRYPOINT ["/opt/drone-chef/drone-chef"]
