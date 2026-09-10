#!/bin/sh
set -eu
# The local bind can retain the PID after a container stops.
rm -f /app/tmp/pids/server.pid
exec bundle exec rails server -b 0.0.0.0 -p 3000
