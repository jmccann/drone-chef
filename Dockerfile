# Docker image for the chef plugin
#
#     docker build --rm=true -t jmccann/drone-chef .

FROM jmccann/drone-chefdk

RUN chef gem install knife-supermarket

ADD . /opt/drone-chef/

ENTRYPOINT ["/opt/drone-chef/bin/drone-chef"]
