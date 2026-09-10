FROM node:24.13.0-bookworm-slim AS node
FROM ruby:3.4.4-slim-bookworm
RUN apt-get update && apt-get install -y --no-install-recommends build-essential libpq-dev libvips-dev libyaml-dev git curl ca-certificates pkg-config tzdata && rm -rf /var/lib/apt/lists/*
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx && npm install -g pnpm@10.2.0 && gem install bundler -v 2.5.16
ENV BUNDLE_PATH=/gems BUNDLE_JOBS=4 RAILS_ENV=test NODE_ENV=test
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install
CMD ["bash"]
