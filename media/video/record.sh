#!/bin/sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
footage=$here/footage
build=$repo/.build/video
app=$build/Build/Products/Debug-iphonesimulator/FormhausDemo.app
variant=$footage/build/FormhausDemo.app
bundle=dev.formhaus.demo
simctl=$(xcrun -f simctl)
booted=""

shutdown() {
  timeout 60 xcrun simctl shutdown all >/dev/null 2>&1 || true
}
trap shutdown EXIT INT TERM

wait_for_builds() {
  tries=0
  while pgrep -x xcodebuild >/dev/null || pgrep -x swift-build >/dev/null || pgrep -f 'usr/bin/simctl io' >/dev/null; do
    [ "$tries" -ge 120 ] && { echo "error: another build is still running" >&2; exit 1; }
    [ "$tries" -eq 0 ] && echo "waiting for another build or simulator run to finish"
    tries=$((tries + 1))
    sleep 10
  done
}

build_app() {
  wait_for_builds
  timeout 1500 xcodebuild build -project "$repo/Examples/FormhausDemo/FormhausDemo.xcodeproj" -scheme FormhausDemo \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "$build" -quiet CODE_SIGNING_ALLOWED=NO
  rm -rf "$variant"
  mkdir -p "$(dirname "$variant")"
  cp -R "$app" "$variant"
  cp "$footage/definitions/variant.json" "$variant/project-inquiry.json"
}

boot() {
  [ "$booted" = "$1" ] && return 0
  [ -n "$booted" ] && timeout 60 "$simctl" shutdown "$booted" >/dev/null 2>&1 || true
  timeout 120 "$simctl" boot "$1" >/dev/null 2>&1 || true
  timeout 300 "$simctl" bootstatus "$1" -b >/dev/null
  timeout 30 "$simctl" ui "$1" appearance light
  timeout 30 "$simctl" status_bar "$1" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
  booted=$1
}

install() {
  timeout 30 "$simctl" terminate "$1" "$bundle" >/dev/null 2>&1 || true
  if [ "$2" = variant ]; then
    timeout 120 "$simctl" install "$1" "$variant"
  else
    timeout 120 "$simctl" install "$1" "$app"
  fi
}

launch() {
  if [ "$3" = - ]; then
    timeout 30 "$simctl" launch "$1" "$bundle" -demoScript "$2" >/dev/null
  else
    timeout 30 "$simctl" launch "$1" "$bundle" -demoScript "$2" -demoStop "$3" >/dev/null
  fi
}

record_device() {
  id=$1 udid=$2 script=$3 stop=$4 definition=$5 kind=$6 seconds=$7
  boot "$udid"
  install "$udid" "$definition"
  rm -f "$footage/$id".*
  if [ "$kind" = still ]; then
    launch "$udid" "$script" "$stop"
    sleep "$seconds"
    timeout 30 "$simctl" io "$udid" screenshot --type png "$footage/$id.png" >/dev/null
  else
    timeout -s INT "$seconds" "$simctl" io "$udid" recordVideo --codec h264 --force "$footage/$id.mov" >/dev/null 2>&1 &
    recorder=$!
    sleep 1.5
    launch "$udid" "$script" "$stop"
    wait "$recorder" || true
  fi
  timeout 30 "$simctl" terminate "$udid" "$bundle" >/dev/null 2>&1 || true
  container=$(timeout 30 "$simctl" get_app_container "$udid" "$bundle" data)
  cp "$container/Documents/demo-timeline.json" "$footage/$id.timeline.json"
  echo "recorded $id"
}

cd "$here"
[ -d node_modules ] || npm ci --no-audit --no-fund
mkdir -p "$footage"
node tools/definitions.mjs
timeout 120 node tools/record-mcp.mjs
plan=$(node tools/plan.mjs "$@")
web=$(node tools/plan.mjs --web "$@")
mac=$(node tools/plan.mjs --mac "$@")

if [ -n "$plan" ]; then
  build_app
  wait_for_builds
  echo "$plan" | while read -r id udid script stop definition kind seconds; do
    record_device "$id" "$udid" "$script" "$stop" "$definition" "$kind" "$seconds"
  done
  shutdown
fi

if [ -n "$mac" ]; then
  wait_for_builds
  timeout 1500 swift build -c release --package-path mac --scratch-path "$repo/.build/render-mac" --quiet
  for id in $mac; do
    timeout 120 "$repo/.build/render-mac/release/RenderMac" "$footage/definitions/base.json" "$footage/$id.png" 880 820
    echo "rendered $id"
  done
fi

if [ -n "$web" ]; then
  timeout 300 npx vite build
  echo "$web" | xargs timeout 600 node tools/record-web.mjs
fi

node tools/sync.mjs
