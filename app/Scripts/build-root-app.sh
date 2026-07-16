#!/bin/zsh

set -euo pipefail

app_dir="${0:A:h:h}"
repo_root="${app_dir:h}"
project="$app_dir/AnimaStudio.xcodeproj"
derived_data="${TMPDIR:-/tmp}/AnimaStudioDerived"
configuration="${CONFIGURATION:-Debug}"
product_name="Anima Studio.app"
source_app="$derived_data/Build/Products/$configuration/$product_name"
destination_app="${ANIMA_APP_DESTINATION:-$repo_root/$product_name}"
staging_app="$destination_app.staging"

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate --spec "$app_dir/project.yml"
elif [[ ! -d "$project" ]]; then
  print -u2 "XcodeGen is required because $project has not been generated."
  exit 1
fi

xcodebuild \
  -project "$project" \
  -scheme AnimaStudio \
  -configuration "$configuration" \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  build

rm -rf "$staging_app"
ditto "$source_app" "$staging_app"
"$app_dir/Scripts/embed-animacore-helper.sh" "$staging_app"
# Establish signatures for every nested Mach-O first, then give the spawned
# helper the sandbox-inheritance identity required by macOS. Re-sealing the
# outer app last preserves the main app's own user-selected-file entitlement.
python_app="$staging_app/Contents/Frameworks/Python.framework/Versions/Current/Resources/Python.app"
codesign --force --deep --sign - "$python_app"
codesign --force --deep --sign - "$staging_app"
codesign \
  --force \
  --sign - \
  --entitlements "$app_dir/App/AnimaCoreHelper.entitlements" \
  "$staging_app/Contents/Helpers/animacore-python"
codesign \
  --force \
  --sign - \
  --entitlements "$app_dir/App/AnimaStudio.entitlements" \
  "$staging_app"
codesign --verify --strict --verbose=2 "$python_app"
codesign --verify --deep --strict --verbose=2 "$staging_app"
rm -rf "$destination_app"
mv "$staging_app" "$destination_app"

print "Built $destination_app"
