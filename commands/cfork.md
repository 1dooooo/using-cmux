# cfork - 将会话分叉到新的 cmux 面板

立即用一次 bash 执行以下命令（如有参数，将 `right` 替换为该方向）:

```bash
S=$(cmux new-split right | awk '{print $2}') && cmux-send --surface "$S" "claude --continue --fork-session\n"
```

无需轮询、Trust 检测、启动确认。用一行报告结果。
