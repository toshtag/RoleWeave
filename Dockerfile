# syntax=docker/dockerfile:1

# ローカル開発用のイメージ。本番用イメージは P0 では扱わない。
#
# バージョンはメジャータグやフローティングタグではなく、パッチまで固定する。

ARG RUBY_VERSION=4.0.6

FROM ruby:${RUBY_VERSION}-slim-bookworm AS development

ENV LANG=C.UTF-8 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3

# apt cache を残さないため、update と install を同じレイヤーで完結させる。
#
# git は bundler-audit が Ruby Advisory Database を取得・更新するために使用する。
# 追加するのは git だけとし、Node.js や npm などの開発基盤は導入しない。
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libpq-dev \
      libvips \
      libyaml-dev \
      pkg-config \
      postgresql-client && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

WORKDIR /workspace

COPY Gemfile Gemfile.lock ./

# lockfile を変更できない状態で解決し、イメージとリポジトリの依存を一致させる。
RUN BUNDLE_FROZEN=true bundle install

COPY . .

ENTRYPOINT ["bin/docker-entrypoint"]

EXPOSE 3000

CMD ["bin/rails", "server", "-b", "0.0.0.0"]
