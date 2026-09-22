#!/usr/bin/env bash
# One-time setup on your Mac. Requires Xcode 27 (for the iOS 27 SDK / Foundation Models) and Homebrew.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate
echo
echo "Project generated: Ledger.xcodeproj"
echo "Next: open Ledger.xcodeproj, select the Ledger target > Signing & Capabilities, choose your Personal Team,"
echo "then change the bundle identifier in project.yml (com.yourname.ledger) to something unique and re-run this script."
