# cmux 快速参考

首先执行 `cmux identify` 确认当前环境，并显示结果。

然后参照以下快速参考来辅助用户操作。

---

## 基本操作

| 操作 | 命令 |
|------|---------|
| 环境确认 | `cmux identify` |
| 工作区列表 | `cmux list-workspaces` |
| 窗口分割（右） | `cmux new-split right` |
| 窗口分割（下） | `cmux new-split down` |
| 读取屏幕 | `cmux read-screen --surface surface:N` |
| 包含回滚 | `cmux read-screen --surface surface:N --scrollback` |
| 发送文本 | `cmux send --surface surface:N "text\n"` |
| 发送按键 | `cmux send-key --surface surface:N return` |
| 关闭表面 | `cmux close-surface --surface surface:N` |
| 通知 | `cmux notify --title "标题" --body "正文"` |

## 换行规则（重要）

**单行**: 在末尾加 `\n` 即可发送。

```bash
cmux send --surface surface:N "echo hello\n"
```

**多行无法用 `\n` 发送**。需要用 `send-key return` 逐行发送:

```bash
cmux send --surface surface:N "echo line1"
cmux send-key --surface surface:N return
cmux send --surface surface:N "echo line2"
cmux send-key --surface surface:N return
```

## 子代理启动最小步骤

1. **窗口分割**: `cmux new-split right` → 获取 surface:N
2. **启动 Claude**: `cmux send --surface surface:N "claude --dangerously-skip-permissions\n"`
3. **Trust 检测**: 轮询 `cmux read-screen --surface surface:N`，检测到 trust 提示后用 `cmux send --surface surface:N "trust\n"`
4. **启动确认**: 用 `read-screen` 检测 Claude Code 启动完成（`$` 或输入提示符 `>`）
5. **发送提示词**: `cmux send --surface surface:N "指示内容"` + `cmux send-key --surface surface:N return`
6. **等待完成**: 轮询 `read-screen` 检测完成标记
7. **回收结果**: `cmux read-screen --surface surface:N --scrollback`

## 故障排查

| 症状 | 处理方式 |
|------|------|
| read-screen 输出为空 | 执行 `cmux refresh-surfaces` 后重试 |
| 找不到 surface | 用 `cmux list-pane-surfaces` 确认最新 ref |
| 多行乱码 | 切换到 `send` + `send-key return` |
| 操作对象搞错 | 用 `cmux identify` 重新确认 caller/focused |

## 环境变量

| 变量 | 用途 |
|------|------|
| `CMUX_SOCKET_PATH` | cmux socket 路径（cmux 内自动设置） |
| `CMUX_WORKSPACE_ID` | 当前工作区 UUID |
| `CMUX_SURFACE_ID` | 当前表面 UUID |

详细内容请参考 using-cmux-zh 技能（SKILL.md）。
