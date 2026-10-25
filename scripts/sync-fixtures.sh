#!/bin/sh
set -eu

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "usage: $0 <git-ref> [path-to-formhaus-repo]" >&2
  exit 1
fi

ref=$1
root=$(cd "$(dirname "$0")/.." && pwd)
source_repo=${2:-$root/../formhaus}

if [ ! -d "$source_repo/.git" ] && ! git -C "$source_repo" rev-parse --git-dir >/dev/null 2>&1; then
  echo "error: $source_repo is not a git repository" >&2
  exit 1
fi

sha=$(git -C "$source_repo" rev-parse --verify "$ref^{commit}")
full_name=$(git -C "$source_repo" rev-parse --symbolic-full-name "$ref" 2>/dev/null || true)
case $ref in
  HEAD | HEAD[~^@]* | @ | @[~^{]*) full_name= ;;
esac
case $full_name in
  refs/heads/* | refs/tags/* | refs/remotes/*) recorded_ref=$ref ;;
  *) recorded_ref=$sha ;;
esac

staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT

sync_dir() {
  source_dir=$1
  parent=$2
  name=$3
  git -C "$source_repo" cat-file -e "$sha:$source_dir" 2>/dev/null || {
    echo "error: $source_dir does not exist at $ref ($sha)" >&2
    exit 1
  }
  git -C "$source_repo" archive --format=tar "$sha" "$source_dir" | tar -x -C "$staging"
  rm -rf "${parent:?}/$name"
  mkdir -p "$parent"
  mv "$staging/$source_dir" "$parent/$name"
  printf 'ref: %s\nsha: %s\n' "$recorded_ref" "$sha" >"$parent/VERSION"
  echo "synced $source_dir at $recorded_ref ($sha)"
}

sync_file() {
  source_file=$1
  target=$2
  git -C "$source_repo" show "$sha:$source_file" >"$target.tmp" || {
    rm -f "$target.tmp"
    echo "error: $source_file does not exist at $ref ($sha)" >&2
    exit 1
  }
  mv "$target.tmp" "$target"
  echo "synced $source_file at $recorded_ref ($sha)"
}

sync_dir packages/core/fixtures/conformance "$root/Tests/FormhausCoreTests/Fixtures" conformance
sync_dir packages/core/tokens "$root/Tests/FormhausUITests/Fixtures" tokens
sync_dir packages/core/locales "$root/Sources/FormhausCore/Resources" locales
sync_file packages/core/__tests__/server/real-world-patterns.json "$root/Tests/FormhausCoreTests/Fixtures/real-world-patterns.json"
