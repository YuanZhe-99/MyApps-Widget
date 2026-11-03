# 交互动作

## 模型

小组件上的控件（复选框、开始按钮）无法运行 Flutter 代码：应用可能并未运行。原生端改为向本机队列追加一条**动作**，重绘小组件，并通知正在运行的应用。应用在下次运行时把排队的动作应用到自己的数据上，发布新的外层封装，然后确认这些动作。

```text
tap → native queue (+ redraw, + "actionsQueued") → app drains → app data → publish → acknowledge
```

动作归应用所有：本包只负责存储和投递，从不解释 `action` 或 `args`。

## 队列格式

队列是一个 JSON 数组，按从旧到新排列，由应用的所有 kind 共用。

```json
[
  {
    "id": "6f1c9d2e-4b5a-4f0e-9a51-0c2f3c1d7e88",
    "kind": "myday.todo",
    "action": "setDone",
    "at": 1767225600000,
    "args": {"id": "task-1", "done": true},
    "instanceId": "list-7"
  }
]
```

| 字段 | 类型 | 含义 |
|---|---|---|
| `id` | 非空字符串 | 每次点击唯一；用于确认 |
| `kind` | 非空字符串 | 控件所属的小组件 kind |
| `action` | 非空字符串 | 应用自有的动作名 |
| `at` | 数字，UTC 毫秒时间戳 | 点击控件的时间 |
| `args` | 对象 | 应用自有的参数；其他类型按 `{}` 读取 |
| `instanceId` | 字符串 | 可选；其他类型按缺失读取 |

## 读取规则

所有读取器（Dart、Kotlin 和 Swift 的 `WidgetActionQueue.decode`）都执行相同的规则，并以 `contract/actions/` 和 `contract/action_expectations.json` 校验：

1. 未存储、JSON 无效或值不是数组 → 空队列。
2. 不是对象、缺少非空字符串 `id`、`kind` 或 `action`、或缺少数字 `at` 的条目会被跳过。布尔值和数字字符串都不算数字。
3. 条目中的未知字段被忽略。

追加时最多保留 200 条，超出时丢弃最旧的。

## 存储

| 平台 | 位置 | 键 |
|---|---|---|
| Android | 私有 `SharedPreferences` 文件 `myapps_widget` | `actions` |
| iOS | App Group `UserDefaults` | `myapps_widget.actions` |

与外层封装一样，队列只保存在本机，从不同步、备份或导出。

## 产生动作

- **Android** — `WidgetActions.pendingIntent(context, kind, action, args, providers, requestCode)` 是发往插件 `WidgetActionReceiver` 的广播；接收器追加动作、重绘给定的 Provider，并在每个已连接的 Flutter 引擎上调用 `actionsQueued`。它适用于所有 Android 版本，也不需要应用正在运行。
- **iOS 17+** — 在小组件视图中使用 `Button(intent: MyAppsWidgetActionIntent(kind:action:args:appGroupId:))`。该 intent 用 `WidgetActionQueue.append` 追加动作，发送 Darwin 通知 `com.yuanzhe.myapps_widget.actions`（应用的插件会把它转成 `actionsQueued`），随后 WidgetKit 重新加载小组件。更早的 iOS 版本没有可交互小组件：请改用 deep link。

## 在应用中处理

```dart
final actions = await bridge.pendingActions();
for (final a in actions) {
  // apply a to the app's data
}
await bridge.publish(updatedEnvelope);
await bridge.acknowledgeActions(actions.map((a) => a.id));
```

在启动、回到前台以及 `setActionsQueuedListener` 回调时处理队列。只在数据写入和发布之后再确认，这样中途崩溃会重新投递而不会丢失点击。由于这种情况下一次点击可能被投递两次，应优先使用幂等动作（设置状态而不是切换状态）。

## 立即显示点击结果

从点击到应用下一次发布之间，小组件读到的仍是旧的外层封装。渲染器会把该 kind 的待处理动作叠加重放到旧封装上（Android 和 iOS 上的 `WidgetActionQueue.pending`）。为避免重放封装中已包含的动作，应用应在其 payload 中列出已应用的动作 id，渲染器跳过这些 id。
