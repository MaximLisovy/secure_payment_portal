#!/usr/bin/env bash
# Builds every brand's release APK and arm64 profile APK into dist/, with hashes
# and the source revision. Existing debug signing is unchanged; artifacts are
# for review/manual testing and dist/ is not committed.
#
#   tool/build_release_apks.sh
#
# Needs flutter (pointed at JDK 21, see README) and jq.
set -euo pipefail

cd "$(dirname "$0")/.."
command -v jq > /dev/null || { echo "jq is required" >&2; exit 1; }

# Replace only this script's artifacts. Remove completion metadata before work,
# so an interrupted build cannot leave an old checksum/revision as a success marker.
mkdir -p dist
rm -f dist/SHA256SUMS dist/SOURCE_REVISION
artifacts=()
for id in $(jq -r '.[].id' android/brands.json); do
  flutter build apk --release --flavor "$id"
  cp "build/app/outputs/flutter-apk/app-${id}-release.apk" "dist/${id}-release.apk"
  artifacts+=("${id}-release.apk")
  flutter build apk --profile --flavor "$id" --target-platform android-arm64
  cp "build/app/outputs/flutter-apk/app-${id}-profile.apk" "dist/${id}-profile-arm64.apk"
  artifacts+=("${id}-profile-arm64.apk")
done

(cd dist && shasum -a 256 -- "${artifacts[@]}" > SHA256SUMS)
git rev-parse HEAD > dist/SOURCE_REVISION
cat dist/SHA256SUMS
