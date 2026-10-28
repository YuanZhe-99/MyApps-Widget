# 外层封装格式

## 结构

每个小组件 kind 存储一个 JSON 对象，即外层封装（envelope）。除 `payload` 归应用所有外，其余顶层字段都归本包所有。

```json
{
  "v": 1,
  "kind": "myday.todoToday",
  "pv": 1,
  "generatedAt": 1767225600000,
  "textScale": 1.0,
  "privacy": "normal",
  "refreshAt": [1767229200000],
  "instanceId": "list-7",
  "payload": {}
}
```

| 字段 | 类型 | 缺失时的默认值 | 含义 |
|---|---|---|---|
| `v` | 整数 | `0`（按当前版本读取） | 外层封装格式版本；本包写入 `1` |
| `kind` | 字符串 | `""` | kind id，小驼峰形式的 `app.widgetName` |
| `pv` | 整数 | `1` | 应用的 payload 版本 |
| `generatedAt` | 整数，UTC 毫秒时间戳 | `0` | 应用构建该封装的时间 |
| `textScale` | 数值 | `1.0` | 字号倍数，限定在 0.9–1.5 并四舍五入到 0.1 |
| `privacy` | 字符串 | `normal` | `normal`、`sensitive` 或 `hidden`；未知值读作 `normal` |
| `refreshAt` | UTC 毫秒时间戳数组 | `[]` | 无需应用即可重绘的时刻；非数值项跳过，结果排序 |
| `instanceId` | 字符串 | 不存在 | 配置型小组件的实例；非字符串被忽略 |
| `payload` | 对象 | 必需 | 应用所有的内容 |

Dart 写入端在改写一个读取到的封装时会保留未知顶层字段（`extraJson`），因此较新的字段不会被旧的写入端丢掉。原生读取端忽略未知字段。

## 读取规则

所有读取端（Dart `WidgetEnvelopeRead.decode`、Kotlin `WidgetEnvelopeRead.decode`、Swift `WidgetEnvelopeRead.decode`）都按相同顺序执行相同检查：

1. 没有存储内容 → `missing`。
2. 不是 JSON 对象，或 `payload` 不是对象 → `invalid`。
3. `v` 大于读取端版本 → `tooNew`。
4. `kind` 与正在渲染的 kind 不同 → `invalid`。
5. 其他情况 → `ok`，按上表取默认值并限定范围。

数值可能以整数或浮点数出现；布尔值永远不算数值。小组件应把 `missing` 渲染为空状态，把 `tooNew` 渲染为「请打开应用更新」，`invalid` 与 `missing` 同样处理。

## 存储

| 平台 | 位置 | 键 |
|---|---|---|
| Android | 私有 `SharedPreferences` 文件 `myapps_widget` | `envelope.<kind>` |
| iOS | App Group `UserDefaults`（`appGroupId` 由应用提供） | `myapps_widget.envelope.<kind>` |

该存储仅在设备本地，应用从不同步、备份或导出它，因此以紧凑 JSON 写入，而非缩进格式。

## 兼容性

`v`、字段名、隐私等级的线上名称、存储键和读取顺序，是与设备上已放置的小组件之间的兼容性约定。只能与三个读取端以及 `contract/` 中的新夹具一起修改；任何旧读取端会误读的改动都要提升 `v`。
