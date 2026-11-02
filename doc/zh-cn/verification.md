# 验证

## 仓库检查

运行 `python3 tool/check_docs.py`。它检查 `doc/en-us` 与 `doc/zh-cn` 页面相同、标题层级相同、表格行数相同、代码块完全一致，并检查本地 Markdown 链接可以解析。它不检查翻译含义；请同时审阅两种语言。

## 包检查

分别在 `packages/myapps_widget_core`、`packages/myapps_widget` 和 `packages/myapps_widget_ui` 中运行：`flutter pub get`、`dart format --set-exit-if-changed lib test`、`flutter analyze`、`flutter test`。CI 使用使用方应用的 Flutter（3.44.2）运行它们。

| 测试 | 覆盖 |
|---|---|
| `myapps_widget_core/test/contract_test.dart` | `contract/` 中的每个夹具与 `expectations.json` 对照 |
| `myapps_widget_core/test/core_test.dart` | 范围限定、带未知字段的往返、id、隐私、deep link |
| `myapps_widget/test/bridge_test.dart` | 通道参数、已放置尺寸、不支持的平台、kind 检查、防抖 |
| `myapps_widget_ui/test/ui_test.dart` | 滑块百分比与范围限定、预览尺寸 |

## 原生检查

| 检查 | 位置 |
|---|---|
| Kotlin 约定测试 `ContractTest` | CI `android` 任务，在 `tool/create_host.sh` 生成的宿主中运行 `./gradlew :myapps_widget:testDebugUnitTest` |
| Android 编译 | CI `android` 任务，在宿主中运行 `flutter build apk --debug` |
| Swift 约定 `tool/check_swift_contract.sh` | CI `apple` 任务（macOS） |
| iOS 插件编译 | CI `apple` 任务，在宿主中运行 `flutter build ios --debug --no-codesign` |

宿主应用没有小组件扩展，因此真实扩展中的 `MyAppsWidgetKit.swift` 只会在使用方应用的 iOS 构建中被编译。放置小组件并观察重绘仍需要真机或模拟器。
