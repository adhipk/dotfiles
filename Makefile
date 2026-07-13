# man-me: name=Makefile
# man-me: category=Repository Setup
# man-me: usage=make test; make install; make diff; make watch; make reload
# man-me: description=Convenience wrappers for tests, source-state and tmux-plugin installation, diff, watch, reload, and native HUD builds.
# man-me: tags=make setup test install apply diff watch reload tmux tpm projectdeck whichkey shortcuts
.PHONY: test test-agent-timer test-dotfiles-lib test-module-lifecycle test-module-integration test-system-uninstall test-dependencies test-control-center test-shortcut-guide test-colorscheme test-configs test-scratchpads test-projects test-hyperspace test-todo test-tmux-session-template test-tmux-workspace test-tmux-which-key test-tmux-persistence test-tmux-border-accent test-tmux-yazi-pane test-source-state test-install test-integration test-whichkey shortcuts-update shortcuts-check install apply apply-debug compile sync diff watch reload clean help build-projectdeck build-whichkey

# Default target
help:
	@echo "Dotfiles Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  make test              - Run all tests"
	@echo "  make test-agent-timer  - Run global agent deadline and sesh lifecycle tests"
	@echo "  make test-dotfiles-lib - Run shared shell standard-library tests"
	@echo "  make test-module-lifecycle - Run module schema and removal-plan tests"
	@echo "  make test-module-integration - Run module-aware install and watch tests"
	@echo "  make test-system-uninstall - Run whole-system removal safety tests"
	@echo "  make test-dependencies - Run normalized dependency inventory tests"
	@echo "  make test-control-center - Run native control-center module tests"
	@echo "  make test-shortcut-guide - Run generated shortcut catalog module tests"
	@echo "  make test-colorscheme  - Run colorscheme tests only"
	@echo "  make test-configs      - Run config file tests only"
	@echo "  make test-scratchpads  - Run scratchpad behavior tests only"
	@echo "  make test-projects     - Run the dormant Projects module tests"
	@echo "  make test-hyperspace   - Run the dormant Hyperspace module tests"
	@echo "  make test-todo         - Run canonical todo.txt wrapper tests only"
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
	@echo "  make shortcuts-update  - Regenerate shortcut JSON and Markdown from desired skhd state"
	@echo "  make shortcuts-check   - Verify checked shortcut artifacts without writing"
	@echo "  make reload            - Reload configurations"
	@echo "  make clean             - Clean up temporary files"

# Run all tests
test:
	@./tests/run_all_tests.sh

# Run individual test suites
test-agent-timer:
	@./tests/test_agent_timer.sh

test-dotfiles-lib:
	@./tests/test_dotfiles_lib.sh

test-module-lifecycle:
	@./tests/test_module_lifecycle.sh

test-module-integration:
	@./tests/test_module_integration.sh

test-system-uninstall:
	@./tests/test_system_uninstall.sh

test-dependencies:
	@./tests/test_dependencies.sh

test-control-center:
	@./tests/test_control_center.sh

test-shortcut-guide:
	@./tests/test_shortcut_guide.sh

test-colorscheme:
	@./tests/test_colorscheme.sh

test-configs:
	@./tests/test_configs.sh

test-scratchpads:
	@./tests/test_scratchpads.sh

test-projects:
	@./tests/test_projects.sh

test-hyperspace:
	@./tests/test_hyperspace.sh

test-todo:
	@./tests/test_todo.sh

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
	@script="$${PROJECTS_MODULE_DIR:-$(CURDIR)/modules/projects}/install/build-projectdeck.sh"; \
	  test -x "$$script" || { echo "projects module build adapter is unavailable: $$script" >&2; exit 1; }; \
	  "$$script"

build-whichkey:
	@./scripts/build-whichkey.sh

shortcuts-update:
	@./modules/shortcut-guide/bin/shortcut-catalog update --root "$(CURDIR)"

shortcuts-check:
	@./modules/shortcut-guide/bin/shortcut-catalog check --root "$(CURDIR)"

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
