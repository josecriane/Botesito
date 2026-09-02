# syntax=docker/dockerfile:1.6
## Build stage --------------------------------------------------------------
# rebar.config pulls dependencies from private git repos over SSH, so the
# build needs an agent forwarded into the build container:
#
#   DOCKER_BUILDKIT=1 docker build --ssh default -t botesito:0.1.0 .
#
# `make image` wires that in.
FROM erlang:28-alpine AS builder

RUN apk add --no-cache build-base git openssh-client yq bash curl

RUN curl -fsSL https://s3.amazonaws.com/rebar3/rebar3 -o /usr/local/bin/rebar3 \
 && chmod +x /usr/local/bin/rebar3 \
 && rebar3 --version

RUN mkdir -p ~/.ssh && ssh-keyscan -t ed25519,rsa github.com >> ~/.ssh/known_hosts

WORKDIR /src
COPY rebar.config rebar.lock Makefile ./
COPY apps ./apps
COPY config ./config
COPY docs ./docs

RUN --mount=type=ssh \
    make spec \
 && rebar3 as prod release

## Runtime stage ------------------------------------------------------------
# Match the builder's Alpine version: NIFs built against alpine:3.23 OpenSSL
# fail to relocate against older releases.
FROM alpine:3.23

RUN apk add --no-cache ncurses-libs libstdc++ libgcc openssl tini

WORKDIR /app
COPY --from=builder /src/_build/prod/rel/botesito /app/release
# The release runs with cwd = /app/release and resolves spec_path relative
# to it, so the generated spec has to sit under /app/release/docs.
COPY --from=builder /src/docs /app/release/docs

# Everything is configured through environment variables:
#
#   BOTESITO_API_TOKEN    required; bearer token callers must present
#   TELEGRAM_BOT_TOKEN    required to actually deliver; from @BotFather
#   TELEGRAM_CHAT_ID      required to actually deliver; numeric chat id
#   BOTESITO_PORT         optional, defaults to 8080
#   BOTESITO_CONFIG       optional path to a YAML config to load first
#
# BEAM sizes its port table from RLIMIT_NOFILE, which containerd leaves at
# ~2 billion. Without +Q that is ~1 GB of anonymous memory on startup.
ENV ERL_FLAGS="+S 2:2 +SDcpu 1:1 +SDio 2 +Q 65536"

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/app/release/bin/botesito", "foreground"]
