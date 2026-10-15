#!/bin/bash
# Installs Homebrew before anything else. Its installer also installs the Xcode Command Line
# Tools (git, make) when they're missing, and asks for an admin password once.
set -euo pipefail

if [ ! -x /opt/homebrew/bin/brew ]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
