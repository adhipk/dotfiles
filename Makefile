# man-me: name=Makefile
# man-me: category=Repository Setup
# man-me: usage=make test; make install; make diff; make watch; make reload
# man-me: description=Convenience wrappers for tests, source-state and tmux-plugin installation, diff, watch, reload, and native HUD builds.
# man-me: tags=make setup test install apply diff watch reload tmux tpm projectdeck whichkey shortcuts
.PHONY: test test-colorscheme test-configs test-projects test-tmux-session-template test-tmux-workspace test-tmux-which-key test-tmux-persistence test-tmux-border-accent test-tmux-yazi-pane test-source-state test-install test-integration test-whichkey install apply apply-debug compile sync diff watch reload clean help build-projectdeck build-whichkey

# Default target
help:
	@echo "Dotfiles Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  make test              - Run all tests"
	@echo "  make test-colorscheme  - Run colorscheme tests only"
	@echo "  make test-configs      - Run config file tests only"
	@echo "  make test-tmux-session-template - Run tmux template tests only"
	@echo "  make test-tmux-workspace - Run declarative tmux layout tests only"
	@echo "  make test-tmux-which-key - Run tmux command-center tests only"
	@echo "  make test-tmux-persistence - Run the isolated Resurrect round-trip"
	@echo "  make test-tmux-border-accent - Run tmux/JankyBorders accent tests only"
	@echo "  make test-tmux-yazi-pane - Run tmux Yazi side-pane tests only"
	@echo "  make test-source-state - Run chezmoi source-state tests only"
	@echo "  make test-install      - Run disposable installer tests only"
	@echo "  make test-integration  - Run integration tests only"
	@echo "  make install           - Apply dotfiles, install tmux plugins, and build native HUDs"
	@echo "  make apply             - Alias for install"
	@echo "  make apply-debug       - Apply dotfiles with verbose chezmoi output"
	@echo "  make compile           - Alias for install"
	@echo "  make sync              - Alias for install"
	@echo "  make diff              - Preview chezmoi changes"
	@echo "  make watch             - Auto-apply source-state changes"
	@echo "  make build-projectdeck - Build the ProjectDeck picker binary"
	@echo "  make build-whichkey    - Build the interactive shortcut guide"
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

test-projects:
	@./tests/test_projects.sh

test-tmux-session-template:
	@./tests/test_tmux_session_template.sh

test-tmux-workspace:
	@./tests/test_tmux_workspace.sh

test-tmux-which-key:
	@./tests/test_tmux_which_key.sh

test-tmux-persistence:
	@./tests/test_tmux_persistence.sh

test-tmux-border-accent:
	@./tests/test_tmux_border_accent.sh

test-tmux-yazi-pane:
	@./tests/test_tmux_yazi_pane.sh

test-source-state:
	@./tests/test_source_state.sh

test-install:
	@./tests/test_install.sh

test-integration:
	@./tests/test_integration.sh

test-whichkey:
	@./tests/test_whichkey.sh

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

build-projectdeck:
	@./scripts/build-projectdeck.sh

build-whichkey:
	@./scripts/build-whichkey.sh

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
