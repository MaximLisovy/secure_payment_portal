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

# Only this script's own files are replaced: anything else in dist/ (a profile APK for a phone) stays.
mkdir -p dist
rm -f dist/*-release.apk dist/SHA256SUMS
for id in $(jq -r '.[].id' android/brands.json); do
  flutter build apk --release --flavor "$id"
  cp "build/app/outputs/flutter-apk/app-${id}-release.apk" "dist/${id}-release.apk"
done

(cd dist && shasum -a 256 -- *-release.apk > SHA256SUMS)
echo
cat dist/SHA256SUMS
