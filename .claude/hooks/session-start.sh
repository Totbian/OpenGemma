#!/bin/bash
set -euo pipefail

# Only run in remote (Claude Code on the web) environments
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# No build dependencies to install for this iOS/Swift project
# (Swift compilation requires Xcode which is macOS-only)

echo "Session start hook completed for OpenGemma"
