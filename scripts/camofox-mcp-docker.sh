#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

docker compose \
  --project-directory "$repo_dir" \
  -f "$repo_dir/docker-compose.yml" \
  up -d camofox-browser >/dev/null

exec docker compose \
  --project-directory "$repo_dir" \
  -f "$repo_dir/docker-compose.yml" \
  --profile mcp \
  run --rm -T --no-deps camofox-mcp
