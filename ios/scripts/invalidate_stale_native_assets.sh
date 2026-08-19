#!/bin/sh
# Flutter 3.38 shares build/native_assets/ios between device and simulator.
# If the cached Mach-O platform does not match this Xcode SDK, drop it and
# also remove leftover copies already inside the app bundle so Thin Binary
# cannot keep embedding the stale framework.
set -e

PROJECT_ROOT="${FLUTTER_APPLICATION_PATH:-$SRCROOT/..}"
CACHE_DIR="${PROJECT_ROOT}/build/native_assets/ios"

expected_platform=""
case "${PLATFORM_NAME:-}" in
  iphoneos) expected_platform=2 ;;
  iphonesimulator) expected_platform=7 ;;
  *) exit 0 ;;
esac

framework_platform() {
  bin="$1"
  [ -f "$bin" ] || return 0
  otool -l "$bin" 2>/dev/null | awk '/cmd LC_BUILD_VERSION/{p=1} p && /platform/{print $2; exit}'
}

stale=0
if [ -d "$CACHE_DIR" ]; then
  for fw in "$CACHE_DIR"/*.framework; do
    [ -d "$fw" ] || continue
    bin="$fw/$(basename "$fw" .framework)"
    platform=$(framework_platform "$bin")
    if [ -n "$platform" ] && [ "$platform" != "$expected_platform" ]; then
      echo "note: Stale native asset $(basename "$fw") has Mach-O platform $platform (need $expected_platform for $PLATFORM_NAME)."
      stale=1
      break
    fi
  done
fi

if [ "$stale" = "1" ]; then
  echo "note: Clearing $CACHE_DIR"
  rm -rf "$CACHE_DIR"
fi

remove_if_stale() {
  fw="$1"
  [ -d "$fw" ] || return 0
  bin="$fw/$(basename "$fw" .framework)"
  platform=$(framework_platform "$bin")
  if [ -n "$platform" ] && [ "$platform" != "$expected_platform" ]; then
    echo "note: Removing leftover $(basename "$fw") from $(dirname "$fw") (platform $platform)"
    rm -rf "$fw"
  fi
}

remove_if_stale "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/objective_c.framework"
if [ -n "${CONFIGURATION_BUILD_DIR:-}" ]; then
  remove_if_stale "${CONFIGURATION_BUILD_DIR}/${WRAPPER_NAME:-Runner.app}/Frameworks/objective_c.framework"
fi
remove_if_stale "${PROJECT_ROOT}/build/ios/iphoneos/Runner.app/Frameworks/objective_c.framework"
remove_if_stale "${PROJECT_ROOT}/build/ios/Debug-iphoneos/Runner.app/Frameworks/objective_c.framework"
