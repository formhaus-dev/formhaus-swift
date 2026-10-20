#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
git log --format='format:%ct' --name-only --no-renames |
  awk '/^[0-9]+$/ { time = $0; next } NF && !seen[$0]++ { print time, $0 }' |
  while read -r time path; do
    [ -f "$path" ] && touch -m -t "$(date -r "$time" +%Y%m%d%H%M.%S)" "$path"
  done
exit 0
