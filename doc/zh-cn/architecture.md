# 架构

## 范围

MyApps-Widget 是 MyApps 系列在 Android 和 iOS 上桌面小组件的共享基础设施。它负责把数据从 Flutter 应用送到原生小组件，并规定这些数据如何存储。它不决定小组件显示什么：payload 内容、原生布局、SwiftUI 视图、文案以及做哪些小组件，都由各应用自己负责。

## 包与组成部分

| 部分 | 职责 |
|---|---|
| `packages/myapps_widget_core` | 纯 Dart：`WidgetEnvelope` 及其容错读取、`WidgetKindDescriptor`、`WidgetPrivacy`、`WidgetTextScale`、`WidgetDeepLink`；不依赖 Flutter |
| `packages/myapps_widget` | Flutter 插件：`MyAppsWidgetBridge`（按 kind 发布和清除、Android 已放置尺寸）、`WidgetRefreshScheduler`（防抖）；包含 Android 与 iOS 原生部分 |
| `packages/myapps_widget_ui` | Flutter 界面：`WidgetPreviewSurface` 和 `WidgetTextScaleControl`；文案由应用注入 |
| Android 部分（`packages/myapps_widget/android`） | `MyAppsWidgetPlugin`、`EnvelopeStore`、`WidgetEnvelopeRead`、`EnvelopeWidgetProvider`、`setScaledTextSize`、`WidgetLaunch` |
| iOS 部分（`packages/myapps_widget/ios`） | `MyAppsWidgetPlugin`：写入 App Group 并重新加载 WidgetKit 时间线 |
| `apple/MyAppsWidgetKit` | 供 WidgetKit 扩展使用的读取端，编译进应用的扩展 target；不依赖 Flutter |
| `contract/` | Dart、Kotlin、Swift 三个读取端必须一致解读的夹具和预期结果 |

依赖单向：`myapps_widget → myapps_widget_core`，`myapps_widget_ui → myapps_widget_core`。界面包从不依赖插件，因此预览可以在没有原生代码的情况下构建和测试。

## 数据流

1. 应用为某个 kind 构建 payload，并用 `MyAppsWidgetBridge.envelope` 包装。
2. `MyAppsWidgetBridge.publish` 通过 `com.yuanzhe.myapps_widget/bridge` 发送编码后的外层封装、该 kind 的 Android Provider 类名、WidgetKit kind 以及 App Group。
3. Android：`EnvelopeStore.write` 把它存进私有的 `myapps_widget` preferences，键为 `envelope.<kind>`；随后 `EnvelopeStore.requestUpdate` 向每个已放置实例的 Provider 广播 `ACTION_APPWIDGET_UPDATE`。iOS：插件把它存进 App Group `UserDefaults`，键为 `myapps_widget.envelope.<kind>`，并对每个 WidgetKit kind 调用 `WidgetCenter.reloadTimelines(ofKind:)`。
4. 原生小组件用 `EnvelopeStore.read`（Android）或 `WidgetEnvelopeStore.read`（iOS）读取自己的 kind，检查状态并渲染 payload。

每个 kind 一份外层封装：发布某个 kind 从不会改写或重绘其他 kind 的小组件。

## 留在应用中的部分

- 构建 payload、它自己的版本号（`pv`），以及在原生端求值。
- `AppWidgetProvider` 子类（通常继承 `EnvelopeWidgetProvider`）、XML 布局、drawable、颜色和 manifest 中的 receiver。
- WidgetKit 扩展 target、其视图、App Group entitlement，以及把 `MyAppsWidgetKit.swift` 加入该 target。
- 文案、设置项存储（例如字号倍数），以及小组件 deep link 的路由。
- 应用内的门面（例如 MyAnime 的 `HomeWidgetService`），让调用方不直接依赖本包。

## 可扩展性规则

- **两层版本。** 外层封装的 `v` 归本包所有；payload 的 `pv` 归应用所有。修改 payload 永远不需要本包发新版本。
- **读取端容错。** 未知字段被忽略（Dart 写入端会保留），缺失字段取默认值，数值被限定范围；更高的 `v` 读作 `tooNew`，小组件可以提示用户打开应用，而不是去猜。
- **kind 是数据。** 新增一个小组件只需一个新的 `WidgetKindDescriptor`、payload 构建函数和原生渲染；本包无需改动。
- **预留字段。** `refreshAt`、`instanceId` 和 `privacy` 在三个平台上都会携带并读取。Android 依据 `refreshAt` 定时重绘、配置型小组件和交互动作尚未实现；见[路线图](#路线图)。
- **存储命名隔离。** 键和 preferences 文件都带 `myapps_widget` 前缀；App Group 由应用提供，本包不写死任何应用标识。

## 路线图

| 项目 | 状态 |
|---|---|
| 外层封装、kind、隐私字段、字号倍数、deep link | 0.1.0 已完成 |
| Android 依据 `refreshAt` 重绘（非精确闹钟） | 仅预留字段 |
| 配置型小组件（`instanceId` 来自 AppIntent 或 configure activity） | 仅预留字段 |
| 交互型小组件（待处理动作队列，由应用下次运行时消费） | 计划中 |
| 共享的 Android drawable 和 SwiftUI 组件 | 计划中 |

见[外层封装格式](envelope.md)、[公开 API](api.md)、[新增小组件](adding-a-widget.md)和[验证](verification.md)。
