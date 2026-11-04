#!/usr/bin/env bash
set -euo pipefail

image="${1:?image reference required}"
# CI-only database and empty Redis. No production secrets, accounts or connectors.
runtime=(--network host
  -e RAILS_ENV=production
  -e TZ=UTC
  -e APP_TIME_ZONE=America/Sao_Paulo
  -e URA_HML_TIMEZONE_REDIS_URL=redis://127.0.0.1:6379/15
  -e POSTGRES_HOST=127.0.0.1
  -e POSTGRES_USERNAME=postgres
  -e POSTGRES_PASSWORD=qa-only
  -e POSTGRES_DATABASE=gopure_image_smoke
  -e REDIS_URL=redis://127.0.0.1:6379/0
  -e SECRET_KEY_BASE=isolated-image-smoke-not-for-production-20261020
  -e FRONTEND_URL=https://gopure-image-smoke.example
  -e FORCE_SSL=false
  -e NICO_MODE=fixture
  -e JRC_CAMPAIGNS_EVOLUTION_CONNECTORS=[]
  -e RAILS_LOG_TO_STDOUT=true)

cleanup() {
  docker logs --tail 15 gopure-evolution-rails-smoke 2>/dev/null || true
  docker logs --tail 15 gopure-evolution-sidekiq-smoke 2>/dev/null || true
  docker logs --tail 15 ura-hml-timezone-sidekiq-smoke 2>/dev/null || true
  docker rm -f gopure-evolution-rails-smoke gopure-evolution-sidekiq-smoke ura-hml-timezone-sidekiq-smoke 2>/dev/null || true
}
trap cleanup EXIT

docker run --rm "${runtime[@]}" "$image" bundle exec rails db:migrate
docker run -d --name gopure-evolution-rails-smoke "${runtime[@]}" "$image" bundle exec rails server -b 127.0.0.1 -p 3010
docker run -d --name gopure-evolution-sidekiq-smoke "${runtime[@]}" "$image" bundle exec sidekiq -r ./config/environment.rb -C config/sidekiq.yml
docker run -d --name ura-hml-timezone-sidekiq-smoke "${runtime[@]}" "$image" bundle exec sidekiq -r ./script/ura_hml_timezone.rb -q ura_hml_timezone_probe

ready=false
for attempt in $(seq 1 30); do
  if curl --fail --silent http://127.0.0.1:3010/api > /tmp/gopure-image-health.json; then
    ready=true
    break
  fi
  sleep 2
done
test "$ready" = true
ruby -rjson -e 'data = JSON.parse(File.read("/tmp/gopure-image-health.json")); abort data.inspect unless data["data_services"] == "ok" && data["queue_services"] == "ok"'
test "$(docker inspect --format '{{.State.Running}}' gopure-evolution-sidekiq-smoke)" = true
test "$(docker inspect --format '{{.State.Running}}' ura-hml-timezone-sidekiq-smoke)" = true
docker exec gopure-evolution-rails-smoke bundle exec rails runner 'require "sidekiq/api"; abort "Sidekiq did not register in Redis" unless Sidekiq::ProcessSet.new.any?; puts "Sidekiq registered in isolated Redis"'
docker exec gopure-evolution-rails-smoke bundle exec rails runner script/ura_hml_timezone_check.rb
echo 'Production image: Rails HTTP, PostgreSQL, Redis and Sidekiq startup passed.'
