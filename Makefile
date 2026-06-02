.PHONY: test test-colorscheme test-configs test-source-state test-install test-integration install apply apply-debug compile sync diff watch reload clean help

# Default target
help:
	@echo "Dotfiles Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  make test              - Run all tests"
	@echo "  make test-colorscheme  - Run colorscheme tests only"
	@echo "  make test-configs      - Run config file tests only"
	@echo "  make test-source-state - Run chezmoi source-state tests only"
	@echo "  make test-install      - Run disposable installer tests only"
	@echo "  make test-integration  - Run integration tests only"
	@echo "  make install           - Apply dotfiles with chezmoi"
	@echo "  make apply             - Alias for install"
	@echo "  make apply-debug       - Apply dotfiles with verbose chezmoi output"
	@echo "  make compile           - Alias for install"
	@echo "  make sync              - Alias for install"
	@echo "  make diff              - Preview chezmoi changes"
	@echo "  make watch             - Auto-apply source-state changes"
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

test-source-state:
	@./tests/test_source_state.sh

test-install:
	@./tests/test_install.sh

test-integration:
	@./tests/test_integration.sh

# Apply dotfiles
install:
	@./install.sh

# Alias targets (habit-friendly)
apply: install
apply-debug:
	@DOTFILES_DEBUG=1 ./install.sh
compile: install
sync: install

# Preview dotfile changes
diff:
	@chezmoi -S "$(CURDIR)" diff

# Watch for changes and auto-sync (macOS: requires fswatch)
watch:
	@./home/bin/executable_watch-sync

# Reload configurations
reload:
	@reload-colors

# Clean temporary files
clean:
	@rm -f *.tmp *.log
	@echo "Cleaned temporary files"
