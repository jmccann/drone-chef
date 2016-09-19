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
    gli \
    --version '~> 2.14' && \
  gem install --no-ri --no-rdoc \
    mixlib-shellout \
    --version '~> 2.2' && \
  gem install --no-ri --no-rdoc \
    chef \
    --version '~> 12.7' && \
  gem install --no-ri --no-rdoc \
    io-console \
    --version '~> 0.4' && \
  gem install --no-ri --no-rdoc \
    berkshelf \
    --version '~> 4.2' && \
  gem install --no-ri --no-rdoc \
    bigdecimal \
    --version '~> 1.2' && \
  apk del \
    bash \
    libffi-dev \
    perl && \
  rm -rf /var/cache/apk/*

COPY pkg/drone-chef-0.0.0.gem /tmp/

RUN gem install --no-ri --no-rdoc --local \
  /tmp/drone-chef-0.0.0.gem

ENTRYPOINT ["/usr/bin/drone-chef", "upload"]
