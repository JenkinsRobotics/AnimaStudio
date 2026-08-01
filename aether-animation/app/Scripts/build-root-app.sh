#!/bin/zsh

set -euo pipefail

app_dir="${0:A:h:h}"
repo_root="${app_dir:h:h}"  # aether-animation/app → repo root
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
occt_library_dir="/opt/homebrew/opt/opencascade/lib"
if [[ ! -d "$occt_library_dir" ]]; then
  print -u2 "Open CASCADE is required to build first-class STEP support."
  print -u2 "Expected Homebrew installation at $occt_library_dir"
  exit 1
fi
mkdir -p "$staging_app/Contents/Frameworks"
occt_root_libraries=(
  TKernel TKMath TKG2d TKG3d TKGeomBase TKBRep TKGeomAlgo TKTopAlgo
  TKPrim TKMesh TKDE TKXSBase TKDESTEP TKCDF TKLCAF TKVCAF TKXCAF TKService
)
cad_library_queue=()
for name in "${occt_root_libraries[@]}"; do
  cad_library_queue+=("$occt_library_dir/lib${name}.7.9.dylib")
done

# Follow the actual Mach-O dependency graph so the app is self-contained but
# does not ship every Open CASCADE viewer/test module from Homebrew.
queue_index=1
while (( queue_index <= ${#cad_library_queue[@]} )); do
  library="${cad_library_queue[$queue_index]}"
  (( queue_index += 1 ))
  [[ -f "$library" ]] || continue
  while IFS= read -r dependency; do
    if [[ "$dependency" == @rpath/libTK*.dylib ]]; then
      dependency="$occt_library_dir/${dependency:t}"
    fi
    [[ "$dependency" == /opt/homebrew/*.dylib ]] || continue
    if (( ${cad_library_queue[(Ie)$dependency]} == 0 )); then
      cad_library_queue+=("$dependency")
    fi
  done < <(otool -L "$library" | awk 'NR > 1 { print $1 }')
done

for library in "${cad_library_queue[@]}"; do
  [[ -f "$library" ]] || continue
  destination="$staging_app/Contents/Frameworks/${library:t}"
  ditto "$library" "$destination"
  install_name_tool -id "@rpath/${library:t}" "$destination"
done

for destination in "$staging_app/Contents/Frameworks"/*.dylib(N); do
  while IFS= read -r dependency; do
    if [[ "$dependency" == /opt/homebrew/*.dylib \
      && -f "$staging_app/Contents/Frameworks/${dependency:t}" ]]; then
      install_name_tool -change "$dependency" "@rpath/${dependency:t}" "$destination"
    fi
  done < <(otool -L "$destination" | awk 'NR > 1 { print $1 }')
done

# Xcode's debug product keeps the app's linked libraries in a sibling
# `*.debug.dylib`; release builds put them in the launcher. Rewrite every
# Mach-O in Contents/MacOS so either configuration is independently portable.
for executable in "$staging_app/Contents/MacOS"/*(N); do
  file "$executable" | grep -q 'Mach-O' || continue
  while IFS= read -r dependency; do
    if [[ "$dependency" == /opt/homebrew/*.dylib \
      && -f "$staging_app/Contents/Frameworks/${dependency:t}" ]]; then
      install_name_tool -change "$dependency" "@rpath/${dependency:t}" "$executable"
    fi
  done < <(otool -L "$executable" | awk 'NR > 1 { print $1 }')
done
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
