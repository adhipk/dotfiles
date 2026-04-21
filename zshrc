# Minimal zsh configuration
export PATH="$HOME/.local/bin:$PATH"
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
export EDITOR=nvim

# Zsh plugins

source ~/antigen.zsh
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zsh-completions
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle zsh-users/zsh-history-substring-search
# Starship prompt
export STARSHIP_CONFIG="$HOME/dotfiles/starship.toml"
antigen apply
eval "$(starship init zsh)"
bindkey '^[[A' history-substring-search-up # or '\eOA'
bindkey '^[[B' history-substring-search-down # or '\eOB'
HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1

source zsh-syntax-highlighting.zsh
source zsh-history-substring-search.zsh
# Docker completions
fpath=(/Users/adhipkashyap/.docker/completions $fpath)
autoload -Uz compinit
compinit

# Basic aliases
alias python=python3

# bun completions
[ -s "/Users/adhipkashyap/.bun/_bun" ] && source "/Users/adhipkashyap/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
alias ports='sudo lsof -i -n -P | grep LISTEN'
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

# Keep Yazi in sync if you drop to a shell from inside Yazi.
if [[ -n "$YAZI_ID" ]]; then
	function _yazi_cd() {
		ya emit cd "$PWD"
	}
	autoload -Uz add-zsh-hook
	add-zsh-hook zshexit _yazi_cd
fi
eval "$(~/.local/bin/mise activate)"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /opt/homebrew/bin/terraform terraform

# vapi
export VAPI_INSTALL="$HOME/.vapi"
export PATH="$VAPI_INSTALL/bin:$PATH"
export MANPATH=""$HOME/.vapi"/share/man:$MANPATH"

# pnpm
export PNPM_HOME="/Users/adhipkashyap/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

#tmux-sessionizer setup
export TMUX_SESSIONIZER_PATH='/Users/adhipkashyap/tmux-sessionizer'
export PATH="$TMUX_SESSIONIZER_PATH:$PATH"

bindkey -s ^f "tmux-sessionizer\n"
bindkey -s '\eh' "tmux-sessionizer -s 0\n"
bindkey -s '\et' "tmux-sessionizer -s 1\n"
bindkey -s '\en' "tmux-sessionizer -s 2\n"
bindkey -s '\es' "tmux-sessionizer -s 3\n"



# === Claude Code + AWS Bedrock ===
# Keep secrets and machine-specific env out of the repo.
[ -f "$HOME/.zshrc.secrets" ] && source "$HOME/.zshrc.secrets"

export PATH="$HOME/bin:$PATH"
alias roigin="origin"

eval "$(zoxide init zsh)"

# Enable Bedrock integration
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_REGION=us-west-2
export AWS_PROFILE=hoag-digital
