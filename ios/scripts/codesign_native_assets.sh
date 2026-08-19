#!/bin/sh
# Flutter copies package:objective_c as an adhoc-signed framework and, on 3.38,
# may embed the simulator dylib in a device build. Physical iOS then rejects
# install with 0xe8008014. Swap in the matching hooks_runner dylib and re-sign.
set -e

PROJECT_ROOT="${FLUTTER_APPLICATION_PATH:-$SRCROOT/..}"

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

find_dylib() {
  want="$1"
  hooks="${PROJECT_ROOT}/.dart_tool/hooks_runner/shared/objective_c/build"
  [ -d "$hooks" ] || return 1
  found=""
  found_mtime=0
  for dylib in "$hooks"/*/objective_c.dylib; do
    [ -f "$dylib" ] || continue
    plat=$(framework_platform "$dylib")
    [ "$plat" = "$want" ] || continue
    mt=$(stat -f %m "$dylib" 2>/dev/null || echo 0)
    if [ -z "$found" ] || [ "$mt" -ge "$found_mtime" ]; then
      found="$dylib"
      found_mtime="$mt"
    fi
  done
  [ -n "$found" ] || return 1
  printf '%s' "$found"
}

ensure_plist() {
  fw="$1"
  plist="$fw/Info.plist"
  [ -f "$plist" ] && return 0
  cat > "$plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>objective_c</string>
	<key>CFBundleIdentifier</key>
	<string>io.flutter.flutter.native-assets.objective-c</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>objective_c</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleSignature</key>
	<string>????</string>
	<key>CFBundleVersion</key>
	<string>1.0</string>
	<key>MinimumOSVersion</key>
	<string>12.0</string>
</dict>
</plist>
EOF
}

sign_framework() {
  fw="$1"
  if [ "${PLATFORM_NAME:-}" != "iphoneos" ]; then
    return 0
  fi
  if [ "${CODE_SIGNING_ALLOWED:-}" = "NO" ] || [ "${CODE_SIGNING_REQUIRED:-}" = "NO" ]; then
    return 0
  fi
  if [ -z "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
    echo "warning: No EXPANDED_CODE_SIGN_IDENTITY; skip signing $(basename "$fw")"
    return 0
  fi
  echo "note: Re-signing $(basename "$fw") in $(dirname "$fw") with ${EXPANDED_CODE_SIGN_IDENTITY_NAME:-$EXPANDED_CODE_SIGN_IDENTITY}"
  codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --timestamp=none -- "$fw"
}

fix_dir() {
  dir="$1"
  [ -n "$dir" ] || return 0
  case "$dir" in
    /*) ;;
    *) return 0 ;;
  esac
  parent=$(dirname "$dir")
  [ -d "$parent" ] || return 0
  mkdir -p "$dir"
  fw="$dir/objective_c.framework"
  bin="$fw/objective_c"
  plat=$(framework_platform "$bin")
  if [ ! -f "$bin" ] || [ "$plat" != "$expected_platform" ]; then
    dylib=$(find_dylib "$expected_platform") || {
      echo "error: No objective_c.dylib with Mach-O platform $expected_platform in .dart_tool/hooks_runner. Run flutter clean && flutter pub get, then build again." >&2
      exit 1
    }
    echo "note: Installing device/simulator-matching objective_c from $dylib (platform $expected_platform) into $fw"
    mkdir -p "$fw"
    cp "$dylib" "$bin"
    ensure_plist "$fw"
  fi
  ident=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$fw/Info.plist" 2>/dev/null || true)
  case "$ident" in
    io.flutter.flutter.native-assets.*)
      sign_framework "$fw"
      ;;
  esac
}

fix_dir "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
if [ -n "${CONFIGURATION_BUILD_DIR:-}" ]; then
  fix_dir "${CONFIGURATION_BUILD_DIR}/${WRAPPER_NAME:-Runner.app}/Frameworks"
fi
fix_dir "${PROJECT_ROOT}/build/ios/iphoneos/Runner.app/Frameworks"
fix_dir "${PROJECT_ROOT}/build/ios/Debug-iphoneos/Runner.app/Frameworks"
