---
name: using-cmux
description: "cmux 终端内操作技能。用于窗口分割、子代理启动/监控/结果收集、命令发送、屏幕读取、通知。当 CMUX_* 环境变量存在时触发。"
---

# 使用 cmux

cmux 是一个终端复用器。通过 CLI 进行窗口分割、命令发送、屏幕读取。
如果存在 `CMUX_SOCKET_PATH` 环境变量，说明正在 cmux 内运行。

## 快速概览

```bash
cmux identify                    # 确认自己的工作区/表面
cmux list-workspaces             # 所有工作区列表
cmux tree                        # 拓扑结构展示
```

资源使用短格式 refs 引用: `window:1`, `workspace:2`, `pane:3`, `surface:4`。
也可用 `--id-format uuids` 输出 UUID 格式。

> **注意**: 使用 `cmux-send` 发送多行时，必须使用 `cmux-send-key return`。详见"换行规则"。

## 基本操作

| 操作 | 命令 |
|------|------|
| 窗口分割 | `cmux new-split right`（也支持 left/up/down） |
| 新工作区 | `cmux new-workspace --cwd $(pwd)` |
| 发送命令 | `cmux-send --surface surface:N "command\n"` |
| 发送按键 | `cmux-send-key --surface surface:N return` / `ctrl+c` / `ctrl+d` |
| 读取屏幕 | `cmux-read --surface surface:N [--scrollback]` |
| 关闭表面/工作区 | `cmux close-surface` / `cmux close-workspace` |
| 列表显示 | `cmux list-panes` / `cmux list-pane-surfaces` |

## 换行规则

**这是最重要的规则。**

### 单行命令: 使用 `\n` 即可

```bash
cmux-send --surface surface:1 "echo hello\n"
```

末尾的 `\n` 相当于回车键。

### 多行文本: 必须使用 `cmux-send-key return`

`\n` 不会被作为换行符发送。需要逐行发送，行与行之间使用 `cmux-send-key return`。

```bash
# ✅ 正确做法
cmux-send --surface surface:1 "line 1"
cmux-send-key --surface surface:1 return
cmux-send --surface surface:1 "line 2"
cmux-send-key --surface surface:1 return

# ❌ 错误 — \n 不会变成中间换行
cmux-send --surface surface:1 "line 1\nline 2\n"
```

**规则**: 只有末尾的单个 `\n` 才会作为回车。在字符串中间输入 `\n` 不会产生换行。

## 发送控制键

控制键（如中断进程的 Ctrl+C）必须使用 **`cmux-send-key`** 发送，`cmux-send` 无法发送。

```bash
# ✅ 正确做法
cmux-send-key --surface surface:N ctrl+c

# ❌ 错误 — 只会发送字面文本
cmux-send --surface surface:N "C-c"
cmux-send --surface surface:N "\x03"
cmux-send-key --surface surface:N "C-c"   # → Unknown key 错误
```

按键名称包括 `ctrl+c`, `ctrl+d`, `ctrl+z`, `return`, `tab`, `escape` 等。可通过 `cmux send-key --help` 确认。

## 使用包装器的原则（重要）

**使用 `cmux-read` / `cmux-send` / `cmux-send-key` 包装脚本。** 只要传入 `surface:N`，它们会自动解析正确的工作区，因此即使是不同 workspace/window 的表面，只用 `--surface` 就能操作。

```bash
# ✅ 正确做法 — 从 surface ref 自动解析（可跨 window）
cmux-read --surface surface:N
cmux-send --surface surface:N "command\n"
cmux-send-key --surface surface:N return
```

```bash
# ❌ 错误 — 原生 cmux 命令在其他 workspace/window 的表面会失败
cmux read-screen --surface surface:S    # → "Surface is not a terminal" 错误
cmux send --surface surface:S "..."     # → 同上
```

**原因**: 原生的 `cmux read-screen` / `cmux send` / `cmux send-key` 的 `--surface` 参数仅在调用者同一工作区内的表面有效。包装脚本内部通过 `cmux tree --all --json` 解析 workspace 并用 `--workspace` 方式调用，因此跨 window 也能工作。`--workspace` 格式会直接传递，所以在 `new-workspace` 流程（后述）中也可统一使用。

## 始终创建新的 surface

如果需要独立上下文执行，**不要复用已有 surface，而用 `cmux new-split` 创建新的**。复用可能破坏已有面板的状态（运行中的进程、未保存的工作），很危险。

**触发条件**: 用户指示"在另一个 surface 上""在新的 surface 上""在另一个面板中""split"时，必须使用 `new-split` 创建新的。不要直接在当前 surface 执行。

```bash
SURF=$(cmux new-split right | awk '{print $2}')
cmux-send --surface $SURF "command\n"
# 不需要时关闭
cmux close-surface --surface $SURF
```

## 子代理操作模式

启动子代理、委派任务、回收结果的一系列流程。

### 选择放置方式

| 方式 | 优点 | 注意 |
|------|------|------|
| **同一工作区** (`new-split`) | 避免 PTY 延迟初始化问题 | 布局混乱时用 `cmux-grid` 修复 |
| **独立工作区** (`new-workspace`) | 可用 `close-workspace` 一次性关闭、`rename-workspace` 易于识别 | 受 PTY 延迟初始化问题影响（后述） |

### Step 1a: 放置在同一工作区（推荐）

```bash
SURF=$(cmux new-split right | awk '{print $2}')
cmux rename-tab --surface $SURF "Researcher-1"
```

### Step 1b: 放置在独立工作区

```bash
WS=$(cmux new-workspace --cwd $(pwd) | awk '{print $2}')
cmux rename-workspace --workspace $WS "Researcher-1"
```

> **注意**: 由于 PTY 延迟初始化问题（后述），可能需要先在 GUI 上显示一次工作区。

### Step 2: 启动 Claude Code

```bash
cmux-send --workspace $WS "claude --dangerously-skip-permissions\n"
```

> `--dangerously-skip-permissions` 仅用于可信的任务。

### Step 3: 检测 Trust → 确认

启动后可能立即显示 Trust 确认提示。用 `cmux-read` 轮询，检测到 "trust" 或 "Yes, I trust" 后确认:

```bash
screen=$(cmux-read --workspace $WS)
# 检测到 "trust" → 确认
cmux-send-key --workspace $WS return
```

### Step 4: 检测启动完成

轮询 `cmux-read --workspace $WS` 直到出现 `❯` 提示符。

### Step 5: 发送提示词

```bash
# 单行
cmux-send --workspace $WS "指示文本\n"
cmux set-status $WS "调查中" --icon hammer  # 设置状态

# 多行（用 cmux-send-key return 换行）
cmux-send --workspace $WS "第1行指示"
cmux-send-key --workspace $WS return
cmux-send --workspace $WS "第2行指示"
cmux-send-key --workspace $WS return
```

### Step 6: 检测完成

轮询 `cmux-read --workspace $WS`，检测 `❯` 提示符是否重新出现。

### Step 7: 回收结果 & 清理

```bash
cmux clear-status $WS                                      # 清除状态
result=$(cmux-read --workspace $WS --scrollback)  # 获取全部输出

# 清理: 退出 Claude → 关闭面板
cmux-send --workspace $WS "/exit\n"
sleep 2
cmux close-workspace --workspace $WS                      # 关闭整个工作区
```

> **重要**: 仅执行 `/exit` 只会结束 Claude 进程，面板（surface）仍会残留。必须用 `close-workspace`（或 `close-surface`）关闭面板。`sleep 2` 是为了等待 `/exit` 处理完成。

## new-workspace 的 PTY 延迟初始化问题（Issue #1472）

通过 `cmux new-workspace` 创建的工作区，其终端 PTY **在 GUI 上显示之前不会启动**。
仅调用 `select-workspace` API 不够，需要 GUI 渲染（SwiftUI rendering）。

### 症状

- `cmux-send --surface surface:N` → 返回 OK 但命令不执行（停留在队列中）
- `cmux-read --surface surface:N` → `Surface is not a terminal` 错误
- Socket API `surface.send_text` → 返回 `queued: true` 但未投递
- Socket API `surface.read_text` → `Terminal surface not found`

### 解决方案: AppleScript 菜单点击

需要 macOS 辅助功能权限（系统设置 → 隐私与安全性 → 辅助功能）。

```bash
# 创建工作区后强制 GUI 显示
WS=$(cmux new-workspace --cwd $(pwd) | awk '{print $2}')

# 获取工作区索引
WS_INDEX=$(cmux tree --json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for w in data['windows']:
    for ws in w['workspaces']:
        if ws['ref'] == '$WS':
            print(ws['index'] + 1)")

# 用 AppleScript 菜单点击 → 初始化 PTY
osascript -e "
tell application \"System Events\"
    tell process \"cmux\"
        click menu item \"Workspace $WS_INDEX\" of menu 1 of menu bar item \"View\" of menu bar 1
    end tell
end tell"
sleep 2

# 返回原始工作区
ORIG_INDEX=1  # 原始工作区的 index+1
osascript -e "
tell application \"System Events\"
    tell process \"cmux\"
        click menu item \"Workspace $ORIG_INDEX\" of menu 1 of menu bar item \"View\" of menu bar 1
    end tell
end tell"
```

### 注意: Socket API 的回退行为

Socket API `surface.send_text` / `surface.read_text` 在目标 surface 的 PTY 未初始化时，**会静默回退到 caller 的 surface**。必须检查响应的 `surface_ref` 确认是否发送到了预期的 surface。

## cmux-read 故障排查

| 问题 | 处理方式 |
|------|------|
| 输出为空 / 过时 | 先运行 `cmux refresh-surfaces` 再重新读取 |
| 长输出被截断 | 添加 `--scrollback` |
| 只需要特定行数 | 用 `--lines N` 指定行数 |
| 找不到 surface | 用 `cmux list-pane-surfaces` 重新确认 refs |
| `Surface is not a terminal` | 用了原生 `cmux read-screen` → 替换为 `cmux-read` 包装脚本。或 PTY 延迟初始化问题（见上述解决方案） |

如果 `cmux-read` 结果异常，先运行 `cmux refresh-surfaces` → 重新读取。

## 长时间运行的监控

dev server 或构建等长时间进程，应隔离到专用面板，用 `cmux-read` 定期监控。

```bash
cmux new-split right              # → surface:N
cmux-send --surface surface:N "npm run dev\n"
# 轮询检测 "ready" 等关键词
screen=$(cmux-read --surface surface:N)
```

## 通知

```bash
# 应用内通知（面板高亮、侧边栏徽章。Cmd+Shift+U 导航）
cmux notify --title "完成" --body "构建成功"

# macOS 通知中心（带提示音，在使用其他应用时也能显示）
osascript -e 'display notification "构建完成" with title "Claude" sound name "Glass"'
```

使用场景: 在 cmux 内引起注意 → `cmux notify`，用户在用其他应用 → `osascript`。

## 状态与进度显示

```bash
cmux set-status mykey "处理中" --icon hammer --color "#0099ff"  # 显示在侧边栏
cmux clear-status mykey
cmux set-progress 0.5 --label "构建中..."                     # 进度条（0.0〜1.0）
cmux clear-progress
```

## 浏览器自动化

### 打开与导航

```bash
BSURF=$(cmux browser open https://example.com | awk '{print $2}')  # 打开浏览器
cmux browser $BSURF goto https://google.com   # 导航
cmux browser $BSURF back / forward / reload   # 后退/前进/刷新
cmux browser $BSURF url                        # 获取当前 URL
cmux browser $BSURF focus-webview              # 聚焦浏览器
```

### 快照与元素引用

```bash
cmux browser $BSURF snapshot --interactive   # 获取带 [ref=eN] 标记的快照（操作前必须）
```

输出示例（eN 可作为 CSS 选择器使用）:
```
heading "Welcome" [ref=e1]
button "Submit" [ref=e2]
textbox [ref=e3]
```

| 选项 | 说明 |
|-----------|------|
| `--interactive` / `-i` | 添加 `[ref=eN]` 标记 |
| `--compact` | 紧凑显示 |
| `--max-depth N` | DOM 深度限制 |
| `--selector css` | 仅特定元素 |
| `--cursor` | 包含光标位置信息 |

### 元素操作

选择器可使用 CSS 选择器或快照中的 ref（如 `e2`）。使用 `--snapshot-after` 可在操作后自动获取快照。

```bash
cmux browser $BSURF click e2              # 点击
cmux browser $BSURF dblclick e5           # 双击
cmux browser $BSURF hover e3              # 悬停
cmux browser $BSURF focus e3             # 聚焦
cmux browser $BSURF scroll-into-view e4  # 滚动到视图中
cmux browser $BSURF check e8 / uncheck e8 # 勾选/取消
```

### 表单操作

```bash
cmux browser $BSURF fill e3 "hello"         # 输入（清空后输入）
cmux browser $BSURF type e3 "world"         # 追加输入
cmux browser $BSURF select e7 "option-val"  # 下拉选择
cmux browser $BSURF press Enter             # 按键（Return, Tab, Escape 等）
```

### 查找与确认元素状态

```bash
# find: ARIA 角色 / 文本 / 标签 / 占位符 / alt / title / testid / first / last / nth
cmux browser $BSURF find role button
cmux browser $BSURF find text "Submit"
cmux browser $BSURF find nth 3 --selector "li"

# is: 确认元素状态
cmux browser $BSURF is visible e3    # 是否可见
cmux browser $BSURF is enabled e3   # 是否可用
cmux browser $BSURF is checked e8   # 是否已勾选
```

### 获取数据

```bash
cmux browser $BSURF get url / title               # URL/标题
cmux browser $BSURF get text e3                   # 文本
cmux browser $BSURF get html e3                   # HTML
cmux browser $BSURF get value e3                  # 输入值
cmux browser $BSURF get attr e3 href              # 属性
cmux browser $BSURF get count "button"            # 元素数量
cmux browser $BSURF get box e3                    # 边界框
```

### 等待

```bash
cmux browser $BSURF wait --selector "#loaded" --timeout-ms 10000
cmux browser $BSURF wait --text "Success"
cmux browser $BSURF wait --url-contains "/dashboard"
cmux browser $BSURF wait --load-state complete          # 或 interactive
cmux browser $BSURF wait --function "document.readyState === 'complete'"
```

### JavaScript/DOM 注入

```bash
cmux browser $BSURF eval 'document.querySelector("h1").innerText'
cmux browser $BSURF addinitscript 'window.myFlag = true'  # 在页面加载前注入
cmux browser $BSURF addstyle 'body { background: red }'   # 注入 CSS
```

### iframe/对话框

```bash
cmux browser $BSURF frame selector "#iframe1"   # 切换到 iframe
cmux browser $BSURF frame main                   # 返回主框架

cmux browser $BSURF dialog accept               # confirm/alert 点确定
cmux browser $BSURF dialog dismiss              # 取消
cmux browser $BSURF dialog accept "输入文本" # 在 prompt 中输入
```

### 滚动/截图/调试

```bash
cmux browser $BSURF scroll --dy 500                    # 下移 500px
cmux browser $BSURF scroll --selector "#list" --dy 200 # 元素内滚动
cmux browser $BSURF screenshot --out ~/Desktop/cap.png
cmux browser $BSURF highlight e3                        # 高亮元素
cmux browser $BSURF console list                        # 控制台消息
cmux browser $BSURF errors list                         # JavaScript 错误
```

### snapshot vs screenshot 的使用场景

**原则: 操作/确认元素时使用 `snapshot`。`screenshot` 会大量消耗 token，仅作为最后手段。**

| 目的 | 使用的命令 | 理由 |
|------|------------|------|
| 查找和操作页面上的元素 | `snapshot --interactive` | 返回文本，成本低。可直接用 ref 操作 |
| 确认文本内容/结构 | `snapshot` | 以文本形式获取 DOM 树 |
| 需要确认视觉布局 | `screenshot` | PNG 图片（消耗大量 token） |
| 调试时需要目视确认 | `screenshot` | 仅在快照无法判断时使用 |

想用 `screenshot` 时，先考虑是否能用 `snapshot` 替代。

### 会话与状态管理

```bash
cmux browser $BSURF cookies get / set / clear
cmux browser $BSURF storage local get --key "user"
cmux browser $BSURF storage session set --key "token" --value "xyz"
cmux browser $BSURF state save ~/.browser-state/session.json   # 保存认证状态
cmux browser $BSURF state load ~/.browser-state/session.json   # 恢复
cmux browser $BSURF tab list / new / switch 2 / close 2        # 标签页管理
```

### WKWebView 限制（命令存在但返回 `not_supported` 错误）

以下命令在 `cmux browser --help` 中可见，但在当前 WKWebView 下无法工作:

| 命令 | 错误 |
|---------|--------|
| `viewport <w> <h>` | `browser.viewport.set is not supported on WKWebView` |
| `geo <lat> <lon>` | `browser.geolocation.set is not supported on WKWebView` |
| `offline true/false` | `browser.offline.set is not supported on WKWebView` |
| `trace start/stop` | `browser.trace.start is not supported on WKWebView` |
| `network route/unroute` | `browser.network.route is not supported on WKWebView` |
| `screencast start/stop` | `browser.screencast.start is not supported on WKWebView` |
| `input mouse/keyboard/touch` | `browser.input_mouse is not supported on WKWebView` |

### 浏览器操作常见错误

| 错误 | 正确做法 |
|------|-----------|
| 没有快照就使用 ref | 操作前先用 `snapshot --interactive` 获取 ref |
| 导航后仍使用旧的 ref | 导航后重新快照（ref 在 DOM 变更后失效） |
| 忽略 `dialog` 导致挂起 | 在点击前后加入 `dialog accept/dismiss` |
| 找不到 iframe 内的元素 | 用 `frame selector` 切换后再操作 |

## 环境变量

| 变量 | 说明 |
|------|------|
| `CMUX_SOCKET_PATH` | cmux socket 路径。存在则说明在 cmux 内运行 |
| `CMUX_WORKSPACE_ID` | 当前工作区 ID |
| `CMUX_SURFACE_ID` | 当前表面 ID |

## 常见错误

| 错误 | 正确做法 |
|------|-----------|
| 用 `cmux-send "line1\nline2\n"` 发送多行 | 逐行用 `cmux-send`，行之间用 `cmux-send-key return` |
| 用 UUID 指定 surface | 使用短格式 refs: `surface:1`, `pane:2` |
| 放任同一工作区的布局混乱 | 用 `cmux-grid` 整理，或放到独立工作区 |
| `cmux-read` 结果为空就放弃 | 先运行 `refresh-surfaces` 再重试 |
| 漏掉 Trust 提示导致挂起 | 启动后轮询 `cmux-read` 来检测 |
| 直接调用 `cmux read-screen` / `cmux send` / `cmux send-key` | 使用 `cmux-read` / `cmux-send` / `cmux-send-key` 包装脚本（surface→workspace 自动解析） |
| 用 `cmux-send "C-c"` 或 `cmux-send "\x03"` 发送 Ctrl+C | 使用 `cmux-send-key ctrl+c`（见控制键发送） |
| 被要求"在另一个 surface 上"却用当前 surface 执行 | 先用 `cmux new-split` 创建新 surface 再在其中执行 |
| 复用已有 surface | 原则上用 `new-split` 创建新的，因为可能破坏运行中的进程和状态 |
| 不工作区命名 | 用 `rename-workspace` 标注用途 |
| 以为执行 `/exit` 就完成了清理 | `/exit` → `sleep 2` → `close-workspace` / `close-surface` 关闭面板 |

## 命令快速参考

| 命令 | 说明 |
|---------|------|
| `identify` / `tree` | 环境信息 / 拓扑结构展示 |
| `list-workspaces` / `list-panes` / `list-pane-surfaces` | 列表显示 |
| `new-workspace` / `new-split <dir>` | 工作区/面板创建 |
| `cmux-send` / `cmux-send-key` / `cmux-read` | 输入输出操作（surface→workspace 自动解析包装脚本） |
| `refresh-surfaces` | 强制刷新屏幕缓冲区 |
| `close-surface` / `close-workspace` | 结束资源 |
| `select-workspace` / `rename-workspace` / `rename-tab` | 选择/重命名 |
| `cmux-grid` / `cmux-grid 2x3` | 将面板整理为网格布局 |
| `notify` / `set-status` / `set-progress` | 通知/状态/进度 |
| `wait-for` | 等待信号 |
