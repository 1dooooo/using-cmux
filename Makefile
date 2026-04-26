.PHONY: sync help

help:
	@echo "using-cmux 中文版 - 同步命令"
	@echo ""
	@echo "用法:"
	@echo "  make sync       - 同步上游更新并翻译"
	@echo "  make help       - 显示此帮助"

sync:
	@echo "=== 🔄 同步上游更新并翻译 ==="
	./scripts/sync-and-translate.sh
