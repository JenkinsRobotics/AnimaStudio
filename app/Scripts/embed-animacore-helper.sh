#!/bin/zsh

set -euo pipefail

if [[ $# -ne 1 ]]; then
  print -u2 "Usage: $0 /path/to/Anima\ Studio.app"
  exit 64
fi

app_bundle="$1"
app_dir="${0:A:h:h}"
repo_root="${app_dir:h}"
venv_python="$repo_root/.venv/bin/python"

if [[ ! -x "$venv_python" ]]; then
  print -u2 "AnimaCore helper packaging requires $venv_python."
  exit 1
fi

python_home="$($venv_python -c 'import sys; print(sys.base_prefix)')"
python_version="$($venv_python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
python_executable="$($venv_python -c 'import pathlib, sys; print(pathlib.Path(sys.executable).resolve())')"
yaml_package="$($venv_python -c 'import pathlib, yaml; print(pathlib.Path(yaml.__path__[0]).resolve())')"
numpy_package="$($venv_python -c 'import pathlib, numpy; print(pathlib.Path(numpy.__path__[0]).resolve())')"
python_dependency="$(otool -L "$python_executable" | awk '/Python.framework.*\/Python/{print $1; exit}')"

if [[ -z "$python_dependency" || ! -f "$python_home/Python" ]]; then
  print -u2 "Could not locate the embeddable Python framework used by $venv_python."
  exit 1
fi

helpers_dir="$app_bundle/Contents/Helpers"
framework_dir="$app_bundle/Contents/Frameworks/Python.framework"
framework_version_dir="$framework_dir/Versions/$python_version"
python_resources="$app_bundle/Contents/Resources/AnimaCorePython"
bundled_python="$helpers_dir/animacore-python"
nested_python="$framework_version_dir/Resources/Python.app/Contents/MacOS/Python"

mkdir -p "$helpers_dir" "$framework_dir/Versions" "$python_resources"
ditto "$python_home" "$framework_version_dir"
# Homebrew's framework points site-packages back outside the framework. The
# app carries only the explicit AnimaCore dependencies below, so remove that
# development-machine symlink before signing the self-contained bundle.
if [[ -L "$framework_version_dir/lib/python$python_version/site-packages" ]]; then
  unlink "$framework_version_dir/lib/python$python_version/site-packages"
fi
ln -s "$python_version" "$framework_dir/Versions/Current"
ln -s "Versions/Current/Python" "$framework_dir/Python"
ln -s "Versions/Current/Resources" "$framework_dir/Resources"
ln -s "Versions/Current/Headers" "$framework_dir/Headers"
ditto "$python_executable" "$bundled_python"
ditto "$repo_root/animacore" "$python_resources/animacore"
ditto "$yaml_package" "$python_resources/yaml"
# The DH inverse-kinematics path imports NumPy. Keep it beside the other
# explicit bridge dependencies so the signed app never reaches into the
# developer virtual environment at runtime.
ditto "$numpy_package" "$python_resources/numpy"

install_name_tool \
  -change "$python_dependency" \
  "@executable_path/../Frameworks/Python.framework/Versions/$python_version/Python" \
  "$bundled_python"

# Homebrew's framework launcher execs this nested Python.app binary. Its own
# load command also points back to Homebrew, which the app sandbox correctly
# refuses to open. Keep both launch stages entirely inside the app bundle.
nested_python_dependency="$(
  otool -L "$nested_python" \
    | awk 'NR > 1 && /Python.framework.*\/Python/{print $1; exit}'
)"
if [[ -z "$nested_python_dependency" ]]; then
  print -u2 "Could not locate the framework dependency used by $nested_python."
  exit 1
fi
install_name_tool \
  -change "$nested_python_dependency" \
  "@executable_path/../../../../Python" \
  "$nested_python"
install_name_tool \
  -id "@rpath/Python.framework/Versions/$python_version/Python" \
  "$framework_version_dir/Python"
chmod 755 "$bundled_python"

for executable in "$bundled_python" "$nested_python"; do
  if otool -L "$executable" | grep -Fq "/opt/homebrew/"; then
    print -u2 "Embedded Python still links outside the app bundle: $executable"
    exit 1
  fi
done

print "Embedded AnimaCore helper in $app_bundle"
