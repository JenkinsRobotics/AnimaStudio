#!/bin/zsh
# Build the bundled apps, install a per-user background host, and open setup.
set -euo pipefail
host_dir="${0:A:h}"
repo_root="${host_dir:h:h}"
cd "$repo_root"
print "Aether Studio — installation"
print "[1/5] Checking this Mac"
[[ "$(uname -s)" == "Darwin" ]] || { print "This installer is for macOS. Use the foreground host command on other platforms."; exit 1; }
command -v node >/dev/null && command -v npm >/dev/null || { print "Install Node.js 22.12 or later, then reopen this installer."; exit 1; }
node -e 'const [major,minor]=process.versions.node.split(".").map(Number);process.exit(major>22||(major===22&&minor>=12)?0:1)' || { print "Node.js 22.12 or later is required."; exit 1; }
for utility in launchctl codesign sips iconutil; do
  command -v "$utility" >/dev/null || { print "Missing macOS utility: $utility"; exit 1; }
done
studio_python=""
for candidate in "$repo_root/.venv/bin/python" python3.12 python3.11 /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  if command -v "$candidate" >/dev/null && "$candidate" -c 'import sys;sys.exit(0 if (3,11)<=sys.version_info[:2]<(3,13) else 1)' 2>/dev/null; then
    studio_python="$candidate"
    break
  fi
done
[[ -n "$studio_python" ]] || { print "Install Python 3.11 or 3.12, then reopen this installer."; exit 1; }
if [[ "${1:-}" == "--check" ]]; then
  print "Prerequisites passed. Ready to install."
  exit 0
fi
print "[2/5] Preparing the engine and web applications"
if [[ ! -x .venv/bin/python ]]; then
  "$studio_python" -m venv .venv
fi
.venv/bin/python -m pip install -e .
for package in core/ui studio 'Aether CAD' aether-animation/web; do
  print "Preparing $package"
  npm ci --prefix "$package" --no-audit --no-fund
  npm run build --prefix "$package"
done
print "[3/5] Installing the background host"
.venv/bin/python - <<'PY'
import os
import plistlib
import subprocess
from pathlib import Path
from core.host.__main__ import default_directory
from core.host.state import Store
root = Path.cwd()
directory = default_directory()
Store(directory)
logs = directory / 'logs'
logs.mkdir(exist_ok=True)
plist = Path.home() / 'Library/LaunchAgents/studio.aether.host.plist'
plist.parent.mkdir(parents=True, exist_ok=True)
with plist.open('wb') as file:
    plistlib.dump({
        'Label': 'studio.aether.host',
        'ProgramArguments': [str(root / '.venv/bin/python'), '-m', 'core.host', 'serve'],
        'WorkingDirectory': str(root), 'RunAtLoad': True, 'KeepAlive': True,
        'ThrottleInterval': 10, 'Umask': 63,
        'StandardOutPath': str(logs / 'host.log'),
        'StandardErrorPath': str(logs / 'host-error.log'),
    }, file)
plist.chmod(0o600)
domain = f'gui/{os.getuid()}'
existing = subprocess.run(['launchctl', 'print', domain + '/studio.aether.host'], capture_output=True)
if existing.returncode == 0:
    print('Host already installed and running; saved work has not been interrupted.')
else:
    subprocess.run(['launchctl', 'bootstrap', domain, str(plist)], check=True)
PY
print "[4/5] Creating browser shortcuts"
for application in studio cad animation ui; do
  .venv/bin/python core/host/build-browser-launcher.py "$application"
done
print "[5/5] Opening guided setup"
.venv/bin/python -m core.host open
print "Installation is complete. Finish setup in your browser."
print "Create your administrator, choose applications, and open your workspace."
