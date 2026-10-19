#!/bin/sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
app=$here/../FormhausDemo

swift "$here/render-icons.swift" "$here/logo.svg" "$app/Assets.xcassets"
swift "$here/render-pictures.swift" "$app/Resources/project-inquiry.json"
