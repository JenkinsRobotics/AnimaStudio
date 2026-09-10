#!/bin/zsh
# Double-click to install or repair the local Studio host.
cd "${0:A:h}"
print "Welcome to Aether Studio."
print "This installs the local host and browser shortcuts for your user account."
print "Existing accounts and saved work are kept."
if zsh core/host/install-macos.sh; then
  print "You can close this window and continue in your browser."
else
  print "Installation stopped. Review the message above, correct the issue, then run this installer again."
fi
read "?Press Return to close this window."
