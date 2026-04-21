.PHONY: test test-colorscheme test-configs test-symlinks test-integration install compile sync watch reload clean help

# Default target
help:
	@echo "Dotfiles Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  make test              - Run all tests"
	@echo "  make test-colorscheme  - Run colorscheme tests only"
	@echo "  make test-configs      - Run config file tests only"
	@echo "  make test-symlinks     - Run symlink integrity tests only"
	@echo "  make test-integration  - Run integration tests only"
	@echo "  make install           - Install dotfiles (create symlinks)"
	@echo "  make compile           - Alias for install (sync commands)"
	@echo "  make sync              - Alias for install (sync commands)"
	@echo "  make watch             - Auto-reinstall on file changes"
	@echo "  make reload            - Reload configurations"
	@echo "  make clean             - Clean up temporary files"

# Run all tests
test:
	@./tests/run_all_tests.sh

# Run individual test suites
test-colorscheme:
	@./tests/test_colorscheme.sh

test-configs:
	@./tests/test_configs.sh

test-symlinks:
	@./tests/test_symlinks.sh

test-integration:
	@./tests/test_integration.sh

# Install dotfiles
install:
	@./install.sh

# Alias targets (habit-friendly)
compile: install
sync: install

# Watch for changes and auto-sync (macOS: requires fswatch)
watch:
	@./scripts/watch-sync.sh

# Reload configurations
reload:
	@./reload_colors.sh

# Clean temporary files
clean:
	@rm -f *.tmp *.log
	@echo "Cleaned temporary files"
