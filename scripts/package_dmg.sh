#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="NBA Live"
EXECUTABLE_NAME="NBALiveApp"
BUNDLE_ID="com.coolreatd.nba-live"
VERSION="${1:-v0.1.0}"
DIST_DIR="$ROOT_DIR/dist/$VERSION"
STAGING_DIR="$DIST_DIR/staging"
SWIFTPM_CACHE_DIR="$ROOT_DIR/.cache/swiftpm"
CLANG_CACHE_DIR="$ROOT_DIR/.cache/clang/ModuleCache"

mkdir -p "$DIST_DIR"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
mkdir -p "$SWIFTPM_CACHE_DIR" "$CLANG_CACHE_DIR"

export CLANG_MODULE_CACHE_PATH="$CLANG_CACHE_DIR"
export SWIFT_DRIVER_CLANG_MODULE_CACHE_PATH="$CLANG_CACHE_DIR"

build_for_arch() {
  local arch="$1"
  local label="$2"
  local target_dir="$DIST_DIR/$label"
  local bundle_dir="$target_dir/$APP_NAME.app"
  local contents_dir="$bundle_dir/Contents"
  local macos_dir="$contents_dir/MacOS"
  local resources_dir="$contents_dir/Resources"
  local dmg_staging_dir="$STAGING_DIR/$label"
  local dmg_path="$DIST_DIR/NBA-Live-macOS-$label.dmg"
  local bin_dir

  echo "==> Building $label ($arch)"
  swift build \
    -c release \
    --disable-sandbox \
    --arch "$arch" \
    --cache-path "$SWIFTPM_CACHE_DIR/cache" \
    --config-path "$SWIFTPM_CACHE_DIR/config" \
    --security-path "$SWIFTPM_CACHE_DIR/security" > /dev/null
  bin_dir="$(swift build \
    -c release \
    --disable-sandbox \
    --arch "$arch" \
    --cache-path "$SWIFTPM_CACHE_DIR/cache" \
    --config-path "$SWIFTPM_CACHE_DIR/config" \
    --security-path "$SWIFTPM_CACHE_DIR/security" \
    --show-bin-path)"

  rm -rf "$target_dir" "$dmg_staging_dir" "$dmg_path"
  mkdir -p "$macos_dir" "$resources_dir" "$dmg_staging_dir"

  cp "$bin_dir/$EXECUTABLE_NAME" "$macos_dir/$EXECUTABLE_NAME"
  chmod +x "$macos_dir/$EXECUTABLE_NAME"

  cat > "$contents_dir/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID.$label</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION#v}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION#v}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

  /usr/bin/codesign --force --deep --sign - "$bundle_dir" > /dev/null

  cp -R "$bundle_dir" "$dmg_staging_dir/"
  ln -s /Applications "$dmg_staging_dir/Applications"

  /usr/bin/hdiutil create \
    -volname "$APP_NAME ($label)" \
    -srcfolder "$dmg_staging_dir" \
    -ov \
    -format UDZO \
    "$dmg_path" > /dev/null

  echo "Created $dmg_path"
}

build_for_arch "arm64" "apple-silicon"
build_for_arch "x86_64" "intel"

echo
echo "Artifacts:"
find "$DIST_DIR" -maxdepth 1 -name "*.dmg" -print | sort
