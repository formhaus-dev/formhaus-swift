#!/bin/sh
set -eu

swiftlint_version=0.65.1
swiftlint_sha256=c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0
periphery_version=3.8.0
periphery_sha256=07d4e286e31dd79164df39097e0b59f533c94badbe18158464a455ea88a166d7
jscpd_version=5.4.1

root=$(cd "$(dirname "$0")/.." && pwd)
tools=$root/.build/tools

install_tool() {
  name=$1
  version=$2
  sha256=$3
  url=$4
  dir=$tools/$name-$version
  [ -x "$dir/$name" ] && return 0
  archive=$(mktemp)
  curl -sSfL --retry 3 -o "$archive" "$url"
  echo "$sha256  $archive" | shasum -a 256 -c - >/dev/null || {
    echo "error: checksum mismatch for $name $version" >&2
    rm -f "$archive"
    exit 1
  }
  rm -rf "$dir"
  mkdir -p "$dir"
  unzip -q "$archive" -d "$dir"
  rm -f "$archive"
}

install() {
  install_tool swiftlint "$swiftlint_version" "$swiftlint_sha256" \
    "https://github.com/realm/SwiftLint/releases/download/$swiftlint_version/portable_swiftlint.zip"
  install_tool periphery "$periphery_version" "$periphery_sha256" \
    "https://github.com/peripheryapp/periphery/releases/download/$periphery_version/periphery-$periphery_version.zip"
}

run_format() {
  swift format lint --strict -r Sources Tests Examples Package.swift
}

run_swiftlint() {
  "$tools/swiftlint-$swiftlint_version/swiftlint" lint --strict --quiet
}

run_duplicates() {
  npx --yes "jscpd@$jscpd_version" --config .jscpd.json
}

run_periphery() {
  periphery=$tools/periphery-$periphery_version/periphery
  scratch=$root/.build/periphery
  swift build --build-tests --enable-index-store --scratch-path "$scratch" --quiet
  store=$scratch/debug/index/store
  "$periphery" scan --skip-build --index-store-path "$store" --quiet
  public_config=$(mktemp)
  printf 'retain_public: false\n' >"$public_config"
  redundant=$("$periphery" scan --config "$public_config" --skip-build --index-store-path "$store" --quiet 2>&1 |
    grep 'Redundant public accessibility' || true)
  rm -f "$public_config"
  if [ -n "$redundant" ]; then
    echo "$redundant" >&2
    exit 1
  fi
}

cd "$root"
case ${1:-all} in
  versions) echo "swiftlint-$swiftlint_version-periphery-$periphery_version-jscpd-$jscpd_version" ;;
  install) install ;;
  format) run_format ;;
  swiftlint) install && run_swiftlint ;;
  duplicates) run_duplicates ;;
  periphery) install && run_periphery ;;
  all) install && run_format && run_swiftlint && run_duplicates && run_periphery ;;
  *)
    echo "usage: $0 [all|format|swiftlint|duplicates|periphery|install|versions]" >&2
    exit 1
    ;;
esac
