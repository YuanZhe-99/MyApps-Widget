# 新增小组件

## 应用中的第一个小组件

1. 以相对 URL `../MyApps-Widget.git` 把本仓库作为子模块加到 `packages/myapps_widget`，并依赖 `packages/myapps_widget/packages/myapps_widget`（预览还需要 `myapps_widget_ui`）。
2. 用所有 kind 以及 iOS 的 App Group id 创建一个 `MyAppsWidgetBridge`，并把它放在应用门面之后。
3. Android：照常在 manifest 中声明 Provider。在 `android/app` 中插件的类位于 classpath 上，因此 Provider 可以继承 `EnvelopeWidgetProvider`。
4. iOS：创建 WidgetKit 扩展 target，让应用和扩展使用同一个 App Group entitlement，并把 `../packages/myapps_widget/apple/MyAppsWidgetKit/MyAppsWidgetKit.swift` 加入扩展 target 的源文件（使用文件引用，不要复制）。

## 每个新 kind

1. 选一个形如 `app.widgetName` 的 id，例如 `myday.todoToday`。
2. 注册 `WidgetKindDescriptor`，填入完整限定的 Android Provider 类名、WidgetKit `kind` 字符串、`payloadVersion` 和 `defaultPrivacy`。
3. 在 Dart 中编写 payload 构建函数，以及发布它的 `WidgetRefreshScheduler`；在模块的保存路径中调度它。
4. 编写原生渲染：用 `EnvelopeStore.read` 或 `WidgetEnvelopeStore.read` 读取，处理 `missing`、`invalid` 和 `tooNew`，应用 `textScale`，并遵守 `privacy`。
5. 在应用自己的文档中描述 payload；本仓库从不描述应用的 payload。

```dart
final bridge = MyAppsWidgetBridge(
  appGroupId: 'group.com.example.app',
  kinds: [
    WidgetKindDescriptor(
      id: 'example.today',
      androidProviders: ['com.example.app.widget.TodayProvider'],
      iosKinds: ['ExampleToday'],
    ),
  ],
);

await bridge.publish(bridge.envelope('example.today', {'items': []}));
```

## 隐私

`sensitive` 内容应在设备锁定时隐藏，并在 iOS 上标记 `privacySensitive()`；`hidden` 应绘制中性的占位内容。默认隐私等级不是 `normal` 的 kind 不要提供锁屏样式。
