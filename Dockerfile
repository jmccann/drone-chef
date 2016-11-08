# Docker image for the drone-chef plugin
#
#     docker build --rm=true -t jmccann/drone-chef .

FROM alpine:3.4

# Install required packages
RUN apk update && \
  apk add \
    ca-certificates \
    git \
    ruby && \
  rm -rf /var/cache/apk/*

# Install gems
RUN apk update && \
  apk add \
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
    --version '~> 12.15' && \
  # io-console needed for berkshelf
  gem install --no-ri --no-rdoc \
    io-console \
    --version '~> 0.4' && \
  gem install --no-ri --no-rdoc \
    berkshelf \
    --version '~> 5.2' && \
  apk del \
    ruby-dev \
    build-base \
    bash \
    libffi-dev \
    perl && \
  rm -rf /var/cache/apk/*

COPY pkg/drone-chef-0.0.0.gem /tmp/

RUN gem install --no-ri --no-rdoc --local \
  /tmp/drone-chef-0.0.0.gem

ENTRYPOINT ["/usr/bin/drone-chef", "upload"]
