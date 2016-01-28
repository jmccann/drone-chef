FROM alpine:3.3

RUN apk update && \
  apk add \
    ca-certificates \
    git \
    ruby \
    ruby-dev \
    build-base \
    perl \
    libffi-dev \
    bash && \
  gem install --no-ri --no-rdoc \
    chef \
    berkshelf \
    knife-supermarket && \
  apk del \
    bash \
    libffi-dev \
    perl \
    build-base && \
  rm -rf /var/cache/apk/*

ADD . /opt/drone-chef/
ENTRYPOINT ["/opt/drone-chef/bin/drone-chef"]
