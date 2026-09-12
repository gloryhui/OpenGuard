#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
make clean package
echo "Release archive: $(pwd)/dist/OpenGuard-1.0.0-universal.zip"

