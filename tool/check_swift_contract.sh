#!/usr/bin/env bash
# Purpose: Compile MyAppsWidgetKit with the contract runner and check every fixture.
# Inputs: None; run from anywhere on macOS with Xcode command-line tools.
# Returns: Exit status 0 when the Swift reader matches contract/expectations.json.
# Side effects: Writes a temporary binary.
# Notes: CI runs it on macos-latest; Windows and Linux maintainers rely on CI.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$(mktemp -d)/contract"
swiftc -O "$root/apple/MyAppsWidgetKit/MyAppsWidgetKit.swift" "$root/apple/Tests/main.swift" -o "$out"
cd "$root" && "$out"
