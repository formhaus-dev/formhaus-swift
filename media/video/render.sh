#!/bin/sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
cd "$here"
out=$here/out

[ -d node_modules ] || npm ci --no-audit --no-fund
[ -f footage/manifest.json ] || { echo "error: no footage, run ./record.sh first" >&2; exit 1; }
timeout 300 npx vite build >/dev/null 2>&1
mkdir -p "$out"

timeout 7200 node tools/capture.mjs 2

encode_mp4() {
  timeout 3600 nice -n 10 ffmpeg -v error -y -i "$out/master-2160.mkv" ${3:+-vf "$3"} -c:v libx264 -preset slow -crf "$2" -profile:v high \
    -pix_fmt yuv420p -movflags +faststart -an "$1"
}

name=$(node -p "require('./script.json').output.name")
encode_mp4 "$out/$name.mp4" 16
encode_mp4 "$out/$name-1080p.mp4" 16 "scale=1920:1080:flags=lanczos"
timeout 3600 nice -n 10 ffmpeg -v error -y -i "$out/master-2160.mkv" -vf "scale=1920:1080:flags=lanczos" -c:v libvpx-vp9 -crf 30 -b:v 0 \
  -row-mt 1 -deadline good -cpu-used 2 -pix_fmt yuv420p -an "$out/$name.webm"
timeout 1800 node tools/capture.mjs 1 gif
timeout 1800 nice -n 10 node tools/gif.mjs
timeout 300 node tools/poster.mjs
ls -l "$out"
