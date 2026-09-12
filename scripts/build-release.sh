#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
make clean package
release_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
echo "Release artifacts:"
find "$(pwd)/dist" -maxdepth 1 -type f \( -name "OpenGuard-${release_version}-universal.*" -o -name 'SHA256SUMS.txt' \) -print
