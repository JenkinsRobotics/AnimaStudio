#!/bin/zsh

set -euo pipefail

studio_dir="${0:A:h:h}"
repo_root="${studio_dir:h}"
project="$studio_dir/AnimaStudio.xcodeproj"
derived_data="${TMPDIR:-/tmp}/AnimaStudioDerived"
configuration="${CONFIGURATION:-Debug}"
product_name="Anima Studio.app"
source_app="$derived_data/Build/Products/$configuration/$product_name"
destination_app="$repo_root/$product_name"
staging_app="$repo_root/.Anima Studio.app.staging"

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate --spec "$studio_dir/project.yml"
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
codesign --force --deep --sign - "$staging_app"
rm -rf "$destination_app"
mv "$staging_app" "$destination_app"

print "Built $destination_app"
