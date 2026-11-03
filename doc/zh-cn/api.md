# 公开 API

## myapps_widget_core

| 声明 | 用途 |
|---|---|
| `widgetEnvelopeVersion` | 本包写入且完全理解的外层封装 `v`（`1`） |
| `WidgetEnvelope` | 外层封装；`toJson`、`encode`、`fromJson`（容错），`extraJson` 保留未知字段 |
| `WidgetEnvelopeStatus` | `missing`、`invalid`、`tooNew`、`ok` |
| `WidgetEnvelopeRead.decode(raw, {expectedKind})` | 按约定规则读取存储文本 |
| `WidgetKindDescriptor` | `id`、`androidProviders`、`iosKinds`、`payloadVersion`、`defaultPrivacy`；`isValidId` |
| `WidgetPrivacy` | `normal`、`sensitive`、`hidden`；`wire`、`fromWire` |
| `WidgetTextScale` | `min` 0.9、`max` 1.5、`defaultValue` 1.0、`step` 0.1、`divisions` 6、`clamp` |
| `WidgetDeepLink` | `<scheme>://widget/<kind>?instance=<id>`；`toUri`、`tryParse` |
| `WidgetAction` | 一次排队的点击：`id`、`kind`、`action`、`at`、`args`、`instanceId`；`toJson`、`fromJson`（容错） |
| `WidgetActionQueue` | `decode(raw)`、`encode(actions)`、`maxLength` 200；见[交互动作](actions.md) |

## myapps_widget

`package:myapps_widget/myapps_widget.dart` 会重新导出核心包。

| 声明 | 用途 |
|---|---|
| `MyAppsWidgetBridge({kinds, appGroupId})` | 每个应用一个；拒绝重复的 kind id |
| `MyAppsWidgetBridge.channelName` | `com.yuanzhe.myapps_widget/bridge` |
| `isSupported` | 仅 Android 和 iOS；其他平台上所有调用都不执行任何操作 |
| `envelope(kind, payload, {...})` | 用该 kind 的 `pv` 和默认隐私等级构建外层封装；无副作用 |
| `publish(envelope)` | 存储并重绘该 kind 的小组件 |
| `clear(kind)` | 删除该 kind 的外层封装并重绘 |
| `placedSizes(kind)` | Android：该 kind 各 Provider 每个已放置实例由启动器给出的 dp 边界；在 iOS、其他平台或通道出错时为空 |
| `PlacedWidgetSize` | `provider`、`widgetId`、`minWidth`、`minHeight`、`maxWidth`、`maxHeight`（dp）；`portrait`（最小宽 × 最大高）、`landscape`（最大宽 × 最小高）；`fromMap` 跳过格式错误或尚无尺寸的条目 |
| `pendingActions({kind})` | 已注册 kind 的排队动作，从旧到新；在其他平台或通道出错时为空 |
| `acknowledgeActions(ids)` | 从队列中移除已应用的动作 |
| `setActionsQueuedListener(listener)` | 应用运行期间小组件控件排入动作时被调用 |
| `WidgetRefreshScheduler({onRefresh, delay, onError})` | `schedule`、`flush`、`cancel`、`isPending` |

`publish` 和 `clear` 对未注册的 kind 抛出 `ArgumentError`，在 iOS 上缺少 `appGroupId` 时抛出 `StateError`。kind 缺失、或在 iOS 上 App Group 无法打开时，原生端返回 `bad_args`。

## myapps_widget_ui

| 声明 | 用途 |
|---|---|
| `WidgetPreviewSurface({width, height, child, padding, radius, color})` | 固定尺寸、圆角、着色并裁剪的预览卡片；`smallSide` 172、`stripHeight` 76 |
| `WidgetTextScaleControl({value, onChanged, title, subtitle, leading})` | 带百分比的标题行和基于 `WidgetTextScale` 的滑块；`percent` |

## Android（Kotlin，包 `com.yuanzhe.myapps_widget`）

| 声明 | 用途 |
|---|---|
| `EnvelopeStore.read(context, kind)` | 读取并解码某个 kind 的外层封装 |
| `EnvelopeStore.write`、`clear`、`key`、`prefs` | 存储访问；由插件使用 |
| `EnvelopeStore.requestUpdate(context, providers)` | 向已放置的实例广播 `ACTION_APPWIDGET_UPDATE` |
| `EnvelopeStore.placedSizes(context, providers)` | 每个已放置实例的尺寸选项（dp）；响应 `placedSizes` 通道调用 |
| `WidgetEnvelopeRead.decode(raw, expectedKind)` | 与 Dart 规则相同 |
| `WidgetEnvelope` | 解码后的外层封装；`payload` 为 `JSONObject`；`sp(base)` |
| `WidgetTextScale.clamp`、`WidgetPrivacy.fromWire` | 与 Dart 规则相同 |
| `EnvelopeWidgetProvider` | Provider 基类：实现 `render(context, appWidgetId, options)` |
| `RemoteViews.setScaledTextSize(viewId, baseSp, scale)` | 按倍数设置 sp 字号 |
| `WidgetLaunch.pendingIntent(context, link, requestCode)` | 打开应用的点击动作，可带 deep link |
| `WidgetActions.pendingIntent(context, kind, action, args, providers, requestCode, instanceId)` | 不打开应用、只排入一个应用动作的点击动作 |
| `WidgetActionQueue.pending(context, kind)`、`append`、`remove`、`raw`、`decode` | 待处理动作队列；读取规则与 Dart 相同 |
| `WidgetActionReceiver` | 由插件 manifest 声明；排入点击、重绘并通知正在运行的应用 |

## iOS 扩展（`apple/MyAppsWidgetKit/MyAppsWidgetKit.swift`）

| 声明 | 用途 |
|---|---|
| `WidgetEnvelopeStore.read(kind:appGroupId:)` | 读取并解码某个 kind 的外层封装 |
| `WidgetEnvelopeRead.decode(_:expectedKind:)` | 与 Dart 规则相同 |
| `WidgetEnvelope` | `generatedDate`、`refreshDates`、`pt(_:)`、`decodePayload(_:)` |
| `WidgetTextScale.clamp`、`WidgetPrivacy.fromWire` | 与 Dart 规则相同 |
| `WidgetActionQueue.pending(kind:appGroupId:)`、`append(...)`、`decode(_:)` | 待处理动作队列；读取规则与 Dart 相同 |
| `MyAppsWidgetActionIntent(kind:action:args:appGroupId:)` | 用于 `Button(intent:)` 的 iOS 17+ intent；排入动作并通知正在运行的应用 |
