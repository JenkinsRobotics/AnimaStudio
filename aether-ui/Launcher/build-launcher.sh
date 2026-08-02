#!/bin/zsh
# Assemble "Aether UI.app" at the repo root (same pattern as
# Aether Animation.app; the bundle is gitignored — rebuild any time):
#   1. builds the widget gallery (vite) so dist/ is fresh,
#   2. compiles the WKWebView launcher shell,
#   3. ad-hoc signs the bundle.
set -euo pipefail

launcher_dir="${0:A:h}"
repo_root="${launcher_dir:h:h}"
app_bundle="$repo_root/Aether UI.app"

(cd "$repo_root/aether-ui" && npm run build)

rm -rf "$app_bundle"
mkdir -p "$app_bundle/Contents/MacOS"

swiftc -O -o "$app_bundle/Contents/MacOS/Aether UI" \
  "$launcher_dir/main.swift" \
  -framework AppKit -framework WebKit

cat > "$app_bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Aether UI</string>
  <key>CFBundleDisplayName</key><string>Aether UI</string>
  <key>CFBundleIdentifier</key><string>studio.aether.ui.gallery</string>
  <key>CFBundleExecutable</key><string>Aether UI</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsLocalNetworking</key><true/>
  </dict>
</dict>
</plist>
PLIST

codesign --force --sign - "$app_bundle"
echo "Built $app_bundle"
