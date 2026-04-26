# using-cmux (中文翻译版)

![using-cmux](banner.jpeg)

> **中文翻译版** - 基于 [hummer98/using-cmux](https://github.com/hummer98/using-cmux) 的中文翻译版本。

AI 操作 cmux 的 Claude Code 技能包。

## 动机

Claude Code 内置的 `Agent` 工具虽然方便，但看不到内部发生了什么。难以确认子代理的输出或在中间介入，导致调试和质量管理困难。

**使用 cmux，一切尽收眼底。** 在作为终端复用器运行的 cmux 上启动子代理，可以实时确认每个代理的输入输出，随时介入和修正。

现有的 [hashangit/cmux-skill](https://github.com/hashangit/cmux-skill) 中，浏览器自动化的描述占了约50%，淹没了子代理操作这一真正最重要的使用场景。本包重新调整了结构，**将子代理操作模式置于核心**。

## 概览

本技能覆盖以下内容:

| 类别 | 内容 |
|---------|------|
| **基本操作** | 窗口分割、工作区管理、命令发送、屏幕读取 |
| **换行规则** | 最重要的规则。单行使用 `\n` 与多行使用 `send-key return` 的区别 |
| **子代理启动模式** | 启动 → Trust 检测 → 发送提示词 → 检测完成 → 回收结果的完整流程 |
| **read-screen 故障排查** | 输出为空/过时时的 `refresh-surfaces` 等应对方法 |
| **通知** | `cmux notify`（应用内）与 `osascript`（macOS 通知中心）的使用场景 |
| **状态与进度显示** | 侧边栏状态和进度条的控制 |

## 与 cmux-team 的关系

![架构图](architecture.jpeg)

- **using-cmux**: cmux CLI 的通用操作技能。覆盖从单个子代理启动到结果回收
- **cmux-team**: 多代理编排。负责团队组建/任务分配/同步。以 using-cmux 的操作模式为基础

## 前提条件

- 已安装 [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- 已安装 [cmux](https://cmux.dev)，并在 cmux 会话内运行 Claude Code

## 安装

### 方法1: Plugin（推荐）

```
/plugin marketplace add 1dooooo/using-cmux
/plugin install using-cmux
```

技能、命令、Hook 一次性安装。

**更新:**

```
/plugin update using-cmux
/reload-plugins
```

> 注: 要反映 `bin/` 下包装脚本（如 `cmux-read`）的更新，需要重启 cmux 会话。因为 Plugin 的 `bin/` 路径在会话开始时就被写入 PATH。

### 方法2: Agent Skills（仅技能）

```bash
npx skills add 1dooooo/using-cmux
```

> 注: Agent Skills 不包含命令（`/cmux`）和包装脚本（如 `cmux-read`）。完整功能请使用方式1。

## 使用方法

### 自动触发技能

在 cmux 会话内启动 Claude Code 时，检测到环境变量 `CMUX_SOCKET_PATH` 后会自动加载技能，无需特殊操作。

Claude Code 收到 cmux 操作指示后，会按照 SKILL.md 中描述的模式执行窗口分割、命令发送、子代理启动等操作。

### `/cmux` 命令

显示快速参考:

```
/cmux
```

需要快速查看命令列表和基本用法时使用。

## 许可证

[MIT](LICENSE)
