.PHONY: test test-colorscheme test-scripts test-configs test-symlinks test-integration install reload clean help

# Default target
help:
	@echo "Dotfiles Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  make test              - Run all tests"
	@echo "  make test-colorscheme  - Run colorscheme tests only"
	@echo "  make test-scripts      - Run border script tests only"
	@echo "  make test-configs      - Run config file tests only"
	@echo "  make test-symlinks     - Run symlink integrity tests only"
	@echo "  make test-integration  - Run integration tests only"
	@echo "  make install           - Install dotfiles (create symlinks)"
	@echo "  make reload            - Reload configurations"
	@echo "  make clean             - Clean up temporary files"

# Run all tests
test:
	@./tests/run_all_tests.sh

# Run individual test suites
test-colorscheme:
	@./tests/test_colorscheme.sh

test-scripts:
	@./tests/test_border_scripts.sh

test-configs:
	@./tests/test_configs.sh

test-symlinks:
	@./tests/test_symlinks.sh

test-integration:
	@./tests/test_integration.sh

# Install dotfiles
install:
	@./install.sh

# Reload configurations
reload:
	@./reload_colors.sh

# Clean temporary files
clean:
	@rm -f config/borders/window_colors.json
	@echo "Cleaned temporary files"
