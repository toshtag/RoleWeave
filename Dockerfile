# syntax=docker/dockerfile:1

# ローカル開発用のイメージ。本番用イメージは P0-T4 では扱わない。
#
# バージョンはメジャータグやフローティングタグではなく、パッチまで固定する。
# Debian の世代差による挙動差を避けるため、Ruby と Node.js の双方を Bookworm 系列で揃える。

ARG RUBY_VERSION=4.0.6
ARG NODE_VERSION=24.18.0

FROM node:${NODE_VERSION}-bookworm-slim AS node_runtime
FROM ruby:${RUBY_VERSION}-slim-bookworm AS development

ENV LANG=C.UTF-8 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3

# apt cache を残さないため、update と install を同じレイヤーで完結させる。
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libpq-dev \
      libvips \
      libyaml-dev \
      pkg-config \
      postgresql-client \
      python3 && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Node.js は公式イメージから必要な実体だけを取得する。
# /usr/local 全体をコピーすると Ruby の実行ファイルを上書きしてしまう。
COPY --from=node_runtime /usr/local/bin/node /usr/local/bin/node
COPY --from=node_runtime /usr/local/lib/node_modules /usr/local/lib/node_modules

RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

WORKDIR /workspace

COPY Gemfile Gemfile.lock package.json package-lock.json ./

# lockfile を変更できない状態で解決し、イメージとリポジトリの依存を一致させる。
RUN BUNDLE_FROZEN=true bundle install && \
    npm ci

COPY . .

ENTRYPOINT ["bin/docker-entrypoint"]

EXPOSE 3000

CMD ["bin/rails", "server", "-b", "0.0.0.0"]
