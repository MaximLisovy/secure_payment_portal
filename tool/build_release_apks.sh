#!/usr/bin/env bash
# Builds the release APK of every brand in android/brands.json into dist/, with a SHA256SUMS
# file. The APKs are signed with the debug keys (the repository holds no keystore): they are
# for review, not for a store. dist/ is not committed.
#
#   tool/build_release_apks.sh
#
# Needs flutter (pointed at a JDK 21, see the README) and jq.
set -euo pipefail

cd "$(dirname "$0")/.."
command -v jq > /dev/null || { echo "jq is required" >&2; exit 1; }

rm -rf dist
mkdir dist
for id in $(jq -r '.[].id' android/brands.json); do
  flutter build apk --release --flavor "$id"
  cp "build/app/outputs/flutter-apk/app-${id}-release.apk" "dist/${id}-release.apk"
done

(cd dist && shasum -a 256 -- *.apk > SHA256SUMS)
echo
cat dist/SHA256SUMS
