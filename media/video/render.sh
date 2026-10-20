#!/bin/sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
cd "$here"
scales=${SCALES:-1 2}
out=$here/out

[ -d node_modules ] || npm ci --no-audit --no-fund
[ -f footage/manifest.json ] || { echo "error: no footage, run ./record.sh first" >&2; exit 1; }
timeout 300 npx vite build >/dev/null 2>&1
mkdir -p "$out"

for scale in $scales; do
  timeout 5400 node tools/capture.mjs "$scale"
done

encode_mp4() {
  timeout 3600 ffmpeg -v error -y -i "$1" -c:v libx264 -preset slow -crf "$3" -profile:v high -pix_fmt yuv420p \
    -movflags +faststart -an "$2"
}

name=$(node -p "require('./script.json').output.name")
if [ -f "$out/master-2160.mkv" ] && echo "$scales" | grep -q 2; then
  encode_mp4 "$out/master-2160.mkv" "$out/$name.mp4" 16
fi
if echo "$scales" | grep -q 1; then
  encode_mp4 "$out/master-1080.mkv" "$out/$name-1080p.mp4" 17
  [ -f "$out/$name.mp4" ] || cp "$out/$name-1080p.mp4" "$out/$name.mp4"
  timeout 3600 ffmpeg -v error -y -i "$out/master-1080.mkv" -c:v libvpx-vp9 -crf 30 -b:v 0 -row-mt 1 -deadline good \
    -cpu-used 2 -pix_fmt yuv420p -an "$out/$name.webm"
  timeout 1800 node tools/capture.mjs 1 gif
  timeout 1800 node tools/gif.mjs
fi
timeout 300 node tools/poster.mjs
ls -l "$out"
