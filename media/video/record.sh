#!/bin/sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
footage=$here/footage
build=$repo/.build/video
app=$build/Build/Products/Release-iphonesimulator/FormhausDemo.app
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
  timeout 1500 xcodebuild build -project "$repo/Examples/FormhausDemo/FormhausDemo.xcodeproj" -scheme FormhausDemo -configuration Release \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "$build" -quiet CODE_SIGNING_ALLOWED=NO
}

boot() {
  [ "$booted" = "$1" ] && return 0
  [ -n "$booted" ] && timeout 60 "$simctl" shutdown "$booted" >/dev/null 2>&1 || true
  timeout 120 "$simctl" boot "$1" >/dev/null 2>&1 || true
  timeout 300 "$simctl" bootstatus "$1" -b >/dev/null
  timeout 30 "$simctl" ui "$1" appearance light
  for key in KeyboardAutocorrection KeyboardPrediction KeyboardCheckSpelling KeyboardContinuousPathEnabled KeyboardInlineCompletionEnabled; do
    timeout 30 "$simctl" spawn "$1" defaults write com.apple.Preferences "$key" -bool NO
  done
  timeout 30 "$simctl" ui "$1" content_size "$(node -p "require('./script.json').devices.iphone.contentSize")"
  timeout 30 "$simctl" status_bar "$1" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
  sleep 45
  booted=$1
}

install() {
  timeout 30 "$simctl" terminate "$1" "$bundle" >/dev/null 2>&1 || true
  timeout 120 "$simctl" install "$1" "$app"
}

launch() {
  udid=$1 script=$2 stop=$3 speed=$4
  if [ "$stop" = - ]; then
    timeout 30 "$simctl" launch "$udid" "$bundle" -demoScript "$script" -demoTicker YES -demoWarmup YES -demoSpeed "$speed" >/dev/null
  else
    timeout 30 "$simctl" launch "$udid" "$bundle" -demoScript "$script" -demoTicker YES -demoWarmup YES -demoSpeed "$speed" -demoStop "$stop" >/dev/null
  fi
}

record_device() {
  id=$1 udid=$2 script=$3 stop=$4 definition=$5 kind=$6 seconds=$7 speed=$8
  boot "$udid"
  install "$udid" "$definition"
  quiet
  rm -f "$footage/$id".*
  if [ "$kind" = still ]; then
    launch "$udid" "$script" "$stop" "$speed"
    sleep "$seconds"
    timeout 30 "$simctl" io "$udid" screenshot --type png "$footage/$id.png" >/dev/null
  else
    timeout -s INT "$seconds" "$simctl" io "$udid" recordVideo --codec h264 --force "$footage/raw/$id.mov" >/dev/null 2>&1 &
    recorder=$!
    sleep 1.5
    launch "$udid" "$script" "$stop" "$speed"
    wait "$recorder" || true
  fi
  timeout 30 "$simctl" terminate "$udid" "$bundle" >/dev/null 2>&1 || true
  container=$(timeout 30 "$simctl" get_app_container "$udid" "$bundle" data)
  cp "$container/Documents/demo-timeline.json" "$footage/raw/$id.timeline.json"
  echo "recorded $id"
  [ "$kind" = still ] || nice -n 10 node tools/retime.mjs "$id" 2>/dev/null
}

quiet() {
  tries=0
  while [ "$(sysctl -n vm.loadavg | awk '{print int($2)}')" -ge 3 ] && [ "$tries" -lt 30 ]; do
    tries=$((tries + 1))
    sleep 10
  done
}

smooth() {
  node -e "const r = require('./footage/raw/$1.retime.json'); const moving = require('./script.json').footage['$1'].motion !== false; process.exit(moving && r.gaps.some((gap) => gap.missing > 1) ? 1 : 0)"
}

cd "$here"
[ -d node_modules ] || npm ci --no-audit --no-fund
mkdir -p "$footage/raw"
node tools/definitions.mjs
plan=$(node tools/plan.mjs "$@")
web=$(node tools/plan.mjs --web "$@")
mac=$(node tools/plan.mjs --mac "$@")

if [ -n "$plan" ]; then
  build_app
  wait_for_builds
  echo "$plan" | while read -r id udid script stop definition kind seconds speed; do
    attempt=1
    while :; do
      record_device "$id" "$udid" "$script" "$stop" "$definition" "$kind" "$seconds" "$speed"
      [ "$kind" = still ] || smooth "$id" || [ "$attempt" -ge "${ATTEMPTS:-2}" ] || { attempt=$((attempt + 1)); echo "frame gap in $id, recording again"; continue; }
      break
    done
  done
  shutdown
fi

if [ -n "$mac" ]; then
  wait_for_builds
  timeout 1500 swift build -c release --package-path mac --scratch-path "$repo/.build/render-mac" --quiet
  for id in $mac; do
    width=$(node -p "require('./script.json').devices.mac.window[0]")
    height=$(node -p "require('./script.json').devices.mac.window[1]")
    timeout 120 "$repo/.build/render-mac/release/RenderMac" "$footage/definitions/base.json" "$footage/$id.png" "$width" "$height"
    echo "rendered $id"
  done
fi

if [ -n "$web" ]; then
  timeout 300 npx vite build
  echo "$web" | xargs timeout 600 node tools/record-web.mjs
fi

node tools/sync.mjs
