#!/usr/bin/env bash
# Purpose: Generate a throwaway Flutter app that depends on myapps_widget.
# Inputs: $1 — the directory to create.
# Returns: Exit status 0 when the host resolves.
# Side effects: Creates the directory and runs flutter pub get.
# Notes: Used by CI to compile the Android and iOS plugin code; not committed.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
host="$1"
flutter create --template=app --platforms=android,ios --project-name widget_host "$host" >/dev/null
cd "$host"
flutter pub add "myapps_widget:{\"path\":\"$root/packages/myapps_widget\"}"
flutter pub add "myapps_widget_ui:{\"path\":\"$root/packages/myapps_widget_ui\"}"
flutter pub get
