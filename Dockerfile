# syntax=docker/dockerfile:1
# check=error=true

ARG RUBY_VERSION=3.4.12
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# Extra CA certificates (e.g. a corporate TLS proxy) can be dropped into certs/*.crt; the folder is empty by default.
COPY certs/ /usr/local/share/ca-certificates/
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y ca-certificates curl libjemalloc2 postgresql-client && \
    update-ca-certificates && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV BUNDLE_PATH="/usr/local/bundle" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so" \
    SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"

FROM base AS build-base

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

FROM build-base AS test

ENV RAILS_ENV="test"

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

CMD ["bash", "-c", "bin/rails db:prepare && bundle exec rspec"]

FROM build-base AS build

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_WITHOUT="development:test"

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile -j 1 --gemfile

COPY . .
RUN bundle exec bootsnap precompile -j 1 app/ lib/

FROM base AS production

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_WITHOUT="development:test"

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
