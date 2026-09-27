# ClipStack · macOS 剪贴板历史（Win+V 风格）

macOS 版的「Win+V」剪贴板历史工具：原生 Swift + AppKit 编写的菜单栏应用，无第三方依赖，内存占用小。

## 功能

- **自动记录**剪贴板中的文本和图片（截图、复制的图片），重复内容自动去重并挪到最前
- **⌥V 全局快捷键**随时唤起悬浮面板（对应 Windows 的 Win+V）
- **搜索过滤**历史记录（输入即过滤，仅匹配文本条目）
- **置顶收藏**常用内容（右键 → 置顶），置顶条目不会被清空或淘汰
- **点击即复制**回剪贴板，支持键盘操作：`↑↓` 选择、`⏎` 复制、`⌘⌫` 删除、`Esc` 关闭
- 菜单栏图标提供：打开面板 / 清空未置顶记录 / 退出
- 密码管理器标记的隐藏内容（ConcealedType）不会被记录

## 构建与运行

```bash
./build.sh
open build/ClipStack.app
```

编译需要 macOS 13+ 和 Xcode Command Line Tools（`xcode-select --install`）。

启动后菜单栏会出现一个剪贴板图标，按 `⌥V` 即可唤起面板。

## 使用说明

| 操作 | 方式 |
|------|------|
| 唤起/隐藏面板 | `⌥V` 或点击菜单栏图标 |
| 搜索 | 打开面板后直接输入 |
| 复制某条内容 | 单击该条，或 `↑↓` 选中后按 `⏎` |
| 置顶 / 取消置顶 | 右键该条 → 置顶 |
| 删除单条 | 右键 → 删除此条，或选中后 `⌘⌫` |
| 清空历史 | 面板左下角按钮或菜单栏菜单（置顶条目保留） |
| 退出 | 菜单栏图标 → 退出 |

## 自定义

- **快捷键**：改 `Sources/AppDelegate.swift` 中 `HotKey(keyCode:modifiers:)` 两处参数，
  例如 `⌘⇧V` → `modifiers: UInt32(cmdKey | shiftKey)`
- **历史容量**：`Sources/ClipboardStore.swift` 中 `maxItems`（默认 200）
- **监听间隔**：`Sources/ClipboardMonitor.swift` 中 `0.4`
- **面板尺寸**：`Sources/PanelController.swift` 中 `Layout.panelWidth / panelHeight`

改完重新执行 `./build.sh` 即可。

## 已知限制

- 历史保存在内存中，**应用退出后清零**（置顶也无法跨启动保留）；如需持久化可在此基础上加文件存储
- 图片以 PNG 形式保存原始数据，大图较多时内存占用会上升
- 不记录文件/富文本格式（只收纯文本和图片）
- 复制回剪贴板后需自行到目标应用 `⌘V` 粘贴

## 常驻后台

系统设置 → 通用 → 登录项 → `+` 选择 `build/ClipStack.app`，即可开机自启。

## 卸载

```bash
pkill -x ClipStack
rm -rf build
```
