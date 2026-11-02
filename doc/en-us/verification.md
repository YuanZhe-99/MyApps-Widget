# Verification

## Repository checks

Run `python3 tool/check_docs.py`. It checks that `doc/en-us` and `doc/zh-cn` have the same pages,
heading levels, table row counts and identical code blocks, and that local Markdown links resolve.
It does not check translation meaning; review both languages together.

## Package checks

In each of `packages/myapps_widget_core`, `packages/myapps_widget` and `packages/myapps_widget_ui`:
`flutter pub get`, `dart format --set-exit-if-changed lib test`, `flutter analyze`,
`flutter test`. CI runs them on the consumers' Flutter (3.44.2).

| Suite | Covers |
|---|---|
| `myapps_widget_core/test/contract_test.dart` | Every fixture in `contract/` against `expectations.json` |
| `myapps_widget_core/test/core_test.dart` | Clamping, round trip with unknown fields, ids, privacy, deep links |
| `myapps_widget/test/bridge_test.dart` | Channel arguments, placed sizes, unsupported platforms, kind checks, debounce |
| `myapps_widget_ui/test/ui_test.dart` | Slider percentage and clamping, preview size |

## Native checks

| Check | Where |
|---|---|
| Kotlin contract test `ContractTest` | CI `android` job, `./gradlew :myapps_widget:testDebugUnitTest` in a host made by `tool/create_host.sh` |
| Android compile | CI `android` job, `flutter build apk --debug` in the host |
| Swift contract `tool/check_swift_contract.sh` | CI `apple` job (macOS) |
| iOS plugin compile | CI `apple` job, `flutter build ios --debug --no-codesign` in the host |

The host app has no widget extension, so `MyAppsWidgetKit.swift` inside a real extension is only
compiled by a consuming app's iOS build. Placing widgets and watching them redraw still needs a
device or simulator.
