#!/bin/sh
set -x

rm -rf /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/*

if [ ! -x /app/node_modules/.bin/vite ]; then
  pnpm install --frozen-lockfile --network-concurrency=1 --child-concurrency=1
fi

echo "Ready to run Vite development server."

exec bundle exec vite dev
