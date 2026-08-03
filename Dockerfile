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

# apt の既定は、導入した直後に取得済みの .deb を捨てる。
# cache mount を用意しても、捨てられた後では次のビルドで使えない。
RUN rm -f /etc/apt/apt.conf.d/docker-clean && \
    printf 'Binary::apt::APT::Keep-Downloaded-Packages "true";\n' \
      > /etc/apt/apt.conf.d/keep-downloaded-packages

# 取得した .deb と package list は cache mount へ置く。
# mount はレイヤーへ含まれないため、イメージへ残さないまま次のビルドで再利用できる。
# 以前はここで rm -rf していたが、捨てていたのは次のビルドで使えたはずのものだった。
#
# git は bundler-audit が Ruby Advisory Database を取得・更新するために使用する。
# 追加するのは git だけとし、Node.js や npm などの開発基盤は導入しない。
#
# PostgreSQL のクライアント（psql、pg_dump）は導入しない。
# 接続は pg gem が libpq を直接呼び、schema_format は既定の :ruby のため
# db:prepare は db/schema.rb を読む。app 側から実行ファイルを呼ぶ経路がない。
# バックアップと復元の手順も db コンテナ側で実行する。
# libpq5 は libpq-dev の依存として残り、pg gem はこちらを使う。
#
# 画像処理のライブラリ（libvips、ImageMagick）は導入しない。
# variant を生成しないと決めており（ADR 0064）、Ruby 側から呼ぶ経路がない。
# 呼ばれないライブラリを入れておくと、更新も脆弱性の追跡も、
# 何のために続けているのか分からないまま残る。
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libpq-dev \
      libyaml-dev \
      pkg-config

WORKDIR /workspace

COPY Gemfile Gemfile.lock ./

# lockfile を変更できない状態で解決し、イメージとリポジトリの依存を一致させる。
#
# 取得した .gem も cache mount へ置く。実行時に読むのは展開後の gems/ だけで、
# cache/ に残る .gem 20 MB は、イメージにも bundle の named volume にも要らない。
#
# target の 4.0.0 は RUBY_VERSION 4.0.6 に対応する ABI である。
# mount の target には ARG を展開できないため直接書き、
# RUBY_VERSION との対応は完全検証で確かめる。
RUN --mount=type=cache,target=/usr/local/bundle/ruby/4.0.0/cache,sharing=locked \
    BUNDLE_FROZEN=true bundle install

COPY . .

EXPOSE 3000

CMD ["bin/rails", "server", "-b", "0.0.0.0"]
