# using-cmux 开发指南

cmux 终端操作的 Claude Code 技能包。
以子代理操作模式为核心，提供结构化的实践知识。

## 文件结构

| 文件 | 职责 |
|---------|------|
| `skills/using-cmux/SKILL.md` | 主技能定义（AI 读取） |
| `commands/cmux.md` | `/cmux` 斜杠命令 |
| `commands/cfork.md` | `/cfork` 会话分叉命令 |
| `bin/cmux-grid` | 将面板整理为网格布局的脚本 |
| `bin/cmux-read` `bin/cmux-send` `bin/cmux-send-key` | surface→workspace 自动解析包装脚本 |
| `bin/cfork` | `/cfork` 用 shell 脚本 |
| `.claude-plugin/plugin.json` | Plugin 清单 |
| `.claude-plugin/marketplace.json` | Marketplace 目录 |
| `README.md` | 用户指南 |
| `CLAUDE.md` | 本开发指南 |
| `LICENSE` | MIT 许可证 |
| `.gitignore` | Git 排除设置 |

## 语言规则

- **文档/注释**: 中文
- **代码（变量名/函数名/命令）**: 英文

## SKILL.md 编辑规则

- **目标约200行**（简洁优先）
- 浏览器操作覆盖 **必要且充分的范围**（与当前 cmux `--help` 对照保持最新）
- **子代理操作模式**为核心章节（~50行）
- **换行规则**维持3层强调:
  1. 专用章节详细说明
  2. 子代理模式内举例
  3. "常见错误"表格中再次强调
- 多用表格和代码示例，散文最少化

## 与 cmux-team 的边界

| 维度 | using-cmux | cmux-team |
|------|-----------|-----------|
| 对象 | 通用 cmux 操作 | 多代理编排 |
| 子代理 | 启动单个→监控→回收结果 | 并行管理多个代理 |
| 范围 | cmux CLI 基本操作全部 | 团队组建/任务分配/同步 |

**避免重复**: using-cmux 不包含 cmux-team 特有功能（团队管理、Issue 管理等）。

## 维护流程

1. 将 `cmux --help` 的输出与 SKILL.md 的命令列表对照，确认一致性
2. cmux 新增命令时更新 SKILL.md
3. 检查 SKILL.md 行数是否大幅超过200行

## 分发

作为 Plugin 分发。`bin/` 下的脚本会被 Claude Code 自动加入 PATH，用户无需额外设置。skills/ commands/ 也通过 Plugin 清单加载。

`/plugin update` 后，PATH 仍指向旧版本（在会话开始时确定）。要反映 `bin/` 的更新，需要重启 cmux 会话。

## bin/ 更新的验证流程

修改 `bin/cmux-*`、`bin/cfork` 等后，**不要在当前会话内验证功能**。因为 PATH 固定在会话开始时的旧版本，你以为调用了修正后的脚本，实际执行的是旧版。

正确验证流程:

1. 发布（或本地执行 `/plugin update`）
2. **打开新的 cmux 窗口或工作区**（重新加载已有标签页不会更新 PATH）
3. 在新会话中确认 `which cmux-send-key` 指向新版本的 `bin/`
4. 创建新 surface 进行功能测试

如果在当前会话测试，会导致误判"明明修了却不行"。
