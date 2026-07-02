SHELL := /bin/bash
DOTFILES_DIR := $(shell pwd)
OS := $(shell uname -s)

# Pin Neovim to the last 0.11.x release for compatibility with
# nvim-treesitter master (master branch was archived; 0.12+ breaks
# the set-lang-from-info-string! injection directive).
NVIM_VERSION := v0.11.6

# On a freshly-installed macOS, Homebrew's installer does not modify the
# current shell's PATH (it only appends `brew shellenv` to ~/.zprofile,
# which affects new login shells). Since each make recipe runs in its own
# non-login shell, brew-installed tools (brew, go, node/npm, tmux, ...)
# are invisible to later targets in the same `make install` run. Prepend
# this to any recipe that depends on brew-installed binaries so it loads
# the Homebrew environment first (Apple Silicon or Intel prefix).
ifeq ($(OS),Darwin)
BREW_ENV := eval "$$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)";
else
BREW_ENV :=
endif

# ============================================================
# Primary targets
# ============================================================

ifeq ($(OS),Darwin)
install: set-xcode set-brew set-packages set-neovim set-rust set-go-packages set-tmux-plugins link set-mermaid-cli set-hunk set-nvim-tools set-default-shell
	@echo "Installation complete. Restart your shell or run: source ~/.zshrc"
	@echo "If tmux is running, reload config: make tmux-reload"
else
install: set-apt-packages set-neovim set-lazygit set-starship set-zoxide set-uv set-ruff set-golang set-rust set-go-packages set-tmux-plugins link set-mermaid-cli set-hunk set-nvim-tools set-default-shell
	@echo "Installation complete. Restart your shell or run: source ~/.zshrc"
	@echo "If tmux is running, reload config: make tmux-reload"
endif

# ============================================================
# macOS prerequisites
# ============================================================

set-xcode:
ifeq ($(OS),Darwin)
	@if xcode-select -p > /dev/null 2>&1; then \
		echo "Xcode command line tools already installed"; \
	else \
		echo "Installing Xcode command line tools (a GUI dialog will appear)..."; \
		xcode-select --install || true; \
		echo "Waiting for Xcode command line tools to finish installing..."; \
		until xcode-select -p > /dev/null 2>&1; do sleep 5; done; \
		echo "Xcode command line tools installed"; \
	fi
else
	@echo "Skipping xcode (not macOS)"
endif

set-brew:
ifeq ($(OS),Darwin)
	@if command -v brew > /dev/null 2>&1; then \
		echo "Homebrew already installed"; \
	else \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"; \
	fi
else
	@echo "Skipping brew (not macOS)"
endif

# ============================================================
# Package installation
# ============================================================

set-packages:
ifeq ($(OS),Darwin)
	$(BREW_ENV) brew update
	$(BREW_ENV) brew bundle --file=$(DOTFILES_DIR)/brewfiles/Brewfile
else
	@echo "On Linux, use: make set-apt-packages"
endif

set-apt-packages:
ifneq ($(OS),Darwin)
	sudo apt update
	sudo apt install -y $$(cat $(DOTFILES_DIR)/packages/apt-packages.txt | grep -v '^#' | grep -v '^$$' | tr '\n' ' ')
else
	@echo "Skipping apt (not Linux)"
endif

set-neovim:
	@INSTALLED_VERSION="$$($(HOME)/.local/bin/nvim --version 2>/dev/null | head -1 | awk '{print $$2}')"; \
	if [ "$$INSTALLED_VERSION" = "$(NVIM_VERSION)" ]; then \
		echo "Neovim $(NVIM_VERSION) already installed at ~/.local/bin/nvim"; \
		exit 0; \
	fi; \
	OS="$(OS)"; ARCH=$$(uname -m); \
	case "$$OS-$$ARCH" in \
		Darwin-arm64) NVIM_TARBALL="nvim-macos-arm64.tar.gz"; NVIM_DIR="nvim-macos-arm64" ;; \
		Darwin-x86_64) NVIM_TARBALL="nvim-macos-x86_64.tar.gz"; NVIM_DIR="nvim-macos-x86_64" ;; \
		Linux-x86_64|Linux-amd64) NVIM_TARBALL="nvim-linux-x86_64.tar.gz"; NVIM_DIR="nvim-linux-x86_64" ;; \
		Linux-aarch64|Linux-arm64) NVIM_TARBALL="nvim-linux-arm64.tar.gz"; NVIM_DIR="nvim-linux-arm64" ;; \
		*) echo "Unsupported platform: $$OS $$ARCH"; exit 1 ;; \
	esac; \
	URL="https://github.com/neovim/neovim/releases/download/$(NVIM_VERSION)/$$NVIM_TARBALL"; \
	echo "Installing Neovim $(NVIM_VERSION) via tarball ($$NVIM_TARBALL)..."; \
	curl -fLo /tmp/$$NVIM_TARBALL "$$URL"; \
	if [ "$$OS" = "Darwin" ]; then xattr -c /tmp/$$NVIM_TARBALL 2>/dev/null || true; fi; \
	tar -xzf /tmp/$$NVIM_TARBALL -C /tmp; \
	if [ "$$OS" = "Darwin" ]; then xattr -cr /tmp/$$NVIM_DIR 2>/dev/null || true; fi; \
	mkdir -p $(HOME)/.local; \
	cp -R /tmp/$$NVIM_DIR/bin $(HOME)/.local/; \
	[ -d /tmp/$$NVIM_DIR/lib ] && cp -R /tmp/$$NVIM_DIR/lib $(HOME)/.local/ || true; \
	cp -R /tmp/$$NVIM_DIR/share $(HOME)/.local/; \
	rm -rf /tmp/$$NVIM_DIR /tmp/$$NVIM_TARBALL; \
	echo "Neovim $(NVIM_VERSION) installed to ~/.local/bin/nvim"; \
	echo "NOTE: ensure \$$HOME/.local/bin precedes /opt/homebrew/bin in PATH"

set-lazygit:
ifneq ($(OS),Darwin)
	@if command -v lazygit > /dev/null 2>&1; then \
		echo "lazygit already installed"; \
	else \
		echo "Installing lazygit from GitHub releases..."; \
		LAZYGIT_VERSION=$$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" \
			| grep -Po '"tag_name": "v\K[^"]*'); \
		ARCH=$$(uname -m); \
		case "$$ARCH" in \
			x86_64|amd64) LG_ARCH="x86_64" ;; \
			aarch64|arm64) LG_ARCH="arm64" ;; \
			*) echo "Unsupported architecture: $$ARCH"; exit 1 ;; \
		esac; \
		curl -fLo /tmp/lazygit.tar.gz \
			"https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_$${LAZYGIT_VERSION}_Linux_$${LG_ARCH}.tar.gz"; \
		tar -xzf /tmp/lazygit.tar.gz -C /tmp lazygit; \
		mkdir -p $(HOME)/.local/bin; \
		install /tmp/lazygit $(HOME)/.local/bin/lazygit; \
		rm -f /tmp/lazygit /tmp/lazygit.tar.gz; \
		echo "lazygit installed to ~/.local/bin/lazygit"; \
	fi
else
	@echo "On macOS, lazygit is installed via brew"
endif

set-starship:
ifneq ($(OS),Darwin)
	@if command -v starship > /dev/null 2>&1; then \
		echo "Starship already installed"; \
	else \
		curl -sS https://starship.rs/install.sh | sh -s -- -y; \
	fi
else
	@echo "On macOS, starship is installed via brew"
endif

set-zoxide:
ifneq ($(OS),Darwin)
	@if command -v zoxide > /dev/null 2>&1; then \
		echo "Zoxide already installed"; \
	else \
		curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh; \
	fi
else
	@echo "On macOS, zoxide is installed via brew"
endif

set-uv:
ifneq ($(OS),Darwin)
	@if command -v uv > /dev/null 2>&1; then \
		echo "uv already installed"; \
	else \
		curl -LsSf https://astral.sh/uv/install.sh | sh; \
	fi
else
	@echo "On macOS, uv is installed via brew"
endif

set-ruff:
ifneq ($(OS),Darwin)
	@if command -v ruff > /dev/null 2>&1; then \
		echo "ruff already installed"; \
	else \
		$(HOME)/.local/bin/uv tool install ruff; \
	fi
else
	@echo "On macOS, ruff is installed via brew"
endif

set-golang:
ifneq ($(OS),Darwin)
	@if [ -x "$(HOME)/.local/go/bin/go" ]; then \
		echo "Go already installed: $$($(HOME)/.local/go/bin/go version)"; \
	else \
		echo "Installing latest Go from go.dev..."; \
		GO_VERSION=$$(curl -sL https://go.dev/VERSION?m=text | head -1); \
		ARCH=$$(uname -m); \
		case "$$ARCH" in \
			x86_64|amd64) GO_ARCH="amd64" ;; \
			aarch64|arm64) GO_ARCH="arm64" ;; \
			*) echo "Unsupported architecture: $$ARCH"; exit 1 ;; \
		esac; \
		curl -fLo /tmp/$$GO_VERSION.linux-$$GO_ARCH.tar.gz \
			https://go.dev/dl/$$GO_VERSION.linux-$$GO_ARCH.tar.gz; \
		mkdir -p $(HOME)/.local; \
		rm -rf $(HOME)/.local/go; \
		tar -C $(HOME)/.local -xzf /tmp/$$GO_VERSION.linux-$$GO_ARCH.tar.gz; \
		rm -f /tmp/$$GO_VERSION.linux-$$GO_ARCH.tar.gz; \
		echo "$$GO_VERSION installed to ~/.local/go"; \
	fi
else
	@echo "On macOS, go is installed via brew"
endif

GO_PACKAGES := \
	golang.org/x/tools/cmd/goimports@latest \
	mvdan.cc/gofumpt@latest \
	github.com/golangci/golangci-lint/cmd/golangci-lint@latest

set-go-packages:
	@$(BREW_ENV) GO_BIN="$$(command -v go || echo "$(HOME)/.local/go/bin/go")"; \
	if [ ! -x "$$GO_BIN" ]; then \
		echo "Go is not installed. Run 'make set-golang' (Linux) or 'make set-packages' (macOS) first."; \
		exit 1; \
	fi; \
	for pkg in $(GO_PACKAGES); do \
		name=$$(basename "$${pkg%%@*}"); \
		if command -v "$$name" > /dev/null 2>&1 || [ -x "$(HOME)/go/bin/$$name" ]; then \
			echo "  OK: $$name"; \
		else \
			echo "  Installing $$name..."; \
			"$$GO_BIN" install "$$pkg"; \
		fi; \
	done; \
	echo "Go packages ready."

set-nvchad-deps:
ifeq ($(OS),Darwin)
	@echo "Installing NvChad dependencies via Homebrew (neovim pinned via set-neovim)..."
	@$(BREW_ENV) brew install uv ruff go
else
	@echo "set-nvchad-deps: on Linux, use set-neovim, set-uv, set-ruff"
endif

ifeq ($(OS),Darwin)
install-nvchad: set-brew set-nvchad-deps set-neovim set-rust set-go-packages link-nvim set-nvim-tools
	@echo "NvChad installation complete."
else
install-nvchad: set-neovim set-uv set-ruff set-golang set-rust set-go-packages link-nvim set-nvim-tools
	@echo "NvChad installation complete."
endif

install-others:
ifeq ($(OS),Darwin)
	$(BREW_ENV) brew update
	$(BREW_ENV) brew bundle --file=$(DOTFILES_DIR)/brewfiles/BrewFile.others
else
	@echo "install-others: only available on macOS (uses Brewfile)"
endif

set-rust:
	@if command -v rustup > /dev/null 2>&1; then \
		echo "Rustup already installed"; \
	else \
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; \
	fi
	@. "$(HOME)/.cargo/env" 2>/dev/null; rustup component add rustfmt clippy

set-mermaid-cli:
	@$(BREW_ENV) if command -v mmdc > /dev/null 2>&1; then \
		echo "mermaid-cli already installed"; \
	else \
		echo "Installing @mermaid-js/mermaid-cli..."; \
		npm install -g @mermaid-js/mermaid-cli; \
	fi

set-hunk:
ifeq ($(OS),Darwin)
	@echo "On macOS, hunk is installed via brew (modem-dev/tap/hunk)"
else
	@if command -v hunk > /dev/null 2>&1; then \
		echo "hunk already installed"; \
	else \
		echo "Installing hunkdiff via npm..."; \
		npm install -g hunkdiff; \
	fi
endif

set-nvim-tools:
	@$(BREW_ENV) [ -f "$(HOME)/.cargo/env" ] && . "$(HOME)/.cargo/env"; \
	export PATH="$(HOME)/.local/bin:$(HOME)/go/bin:$$PATH"; \
	if [ -x "$(HOME)/.local/bin/nvim" ]; then \
		NVIM_BIN="$(HOME)/.local/bin/nvim"; \
	else \
		NVIM_BIN="$$(command -v nvim || true)"; \
	fi; \
	if [ -n "$$NVIM_BIN" ]; then \
		echo "Installing Neovim plugins and Mason tools (headless) with $$NVIM_BIN..."; \
		"$$NVIM_BIN" --headless "+MasonToolsInstallSync" "+qa"; \
	else \
		echo "Failed to install Neovim tools: nvim not found in PATH or ~/.local/bin/nvim."; \
		exit 1; \
	fi

# ============================================================
# Symlinks
# ============================================================

link: link-zshrc link-starship link-dircolors link-gitconfig link-tmux link-tmux-layout link-tmux-rebalance link-tmux-colwidths link-nvim link-ghostty link-puppeteer
	@echo "All symlinks created."

link-zshrc:
	@echo "Linking .zshrc"
	@if [ -f $(HOME)/.zshrc ] && [ ! -L $(HOME)/.zshrc ]; then \
		echo "  Existing ~/.zshrc found (not a symlink). Backing up..."; \
		cp $(HOME)/.zshrc $(HOME)/.zshrc.pre-dotfiles; \
		echo "  Backup saved to ~/.zshrc.pre-dotfiles"; \
		if [ ! -f $(HOME)/.zshrc.local ]; then \
			echo "# Migrated from previous ~/.zshrc ($$(date +%Y-%m-%d))" > $(HOME)/.zshrc.local; \
			cat $(HOME)/.zshrc >> $(HOME)/.zshrc.local; \
			echo "  Migrated existing config to ~/.zshrc.local"; \
		else \
			echo "  ~/.zshrc.local already exists; review ~/.zshrc.pre-dotfiles to merge manually"; \
		fi; \
	fi
	@ln -sf $(DOTFILES_DIR)/zsh/.zshrc $(HOME)/.zshrc

link-starship:
	@echo "Linking starship.toml"
	@mkdir -p $(HOME)/.config
	@ln -sf $(DOTFILES_DIR)/starship/starship.toml $(HOME)/.config/starship.toml

link-dircolors:
	@echo "Linking .dircolors"
	@ln -sf $(DOTFILES_DIR)/dircolors/.dircolors $(HOME)/.dircolors

link-gitconfig:
	@echo "Linking .gitconfig"
	@ln -sf $(DOTFILES_DIR)/git/.gitconfig $(HOME)/.gitconfig

link-tmux:
	@echo "Linking .tmux.conf"
	@ln -sf $(DOTFILES_DIR)/tmux/.tmux.conf $(HOME)/.tmux.conf

link-tmux-layout:
	@echo "Linking tmux-layout script"
	@mkdir -p $(HOME)/.local/bin
	@ln -sf $(DOTFILES_DIR)/tmux/scripts/tmux-layout.sh $(HOME)/.local/bin/tmux-layout

link-tmux-rebalance:
	@echo "Linking tmux-rebalance-column script"
	@mkdir -p $(HOME)/.local/bin
	@ln -sf $(DOTFILES_DIR)/tmux/scripts/tmux-rebalance-column.sh $(HOME)/.local/bin/tmux-rebalance-column

link-tmux-colwidths:
	@echo "Linking tmux-set-column-widths script"
	@mkdir -p $(HOME)/.local/bin
	@ln -sf $(DOTFILES_DIR)/tmux/scripts/tmux-set-column-widths.sh $(HOME)/.local/bin/tmux-set-column-widths

link-nvim:
	@echo "Linking NvChad config"
	@if [ -d $(HOME)/.config/nvim ] && [ ! -L $(HOME)/.config/nvim ]; then \
		echo "  Backing up existing ~/.config/nvim to ~/.config/nvim.bak"; \
		mv $(HOME)/.config/nvim $(HOME)/.config/nvim.bak; \
	fi
	@mkdir -p $(HOME)/.config
	@ln -sfn $(DOTFILES_DIR)/nvim $(HOME)/.config/nvim

link-ghostty:
	@echo "Linking Ghostty config"
	@mkdir -p $(HOME)/.config/ghostty
	@ln -sf $(DOTFILES_DIR)/ghostty/config $(HOME)/.config/ghostty/config

link-puppeteer:
	@echo "Linking puppeteer.json"
	@mkdir -p $(HOME)/.config
	@ln -sf $(DOTFILES_DIR)/puppeteer/puppeteer.json $(HOME)/.config/puppeteer.json

# ============================================================
# Shell configuration
# ============================================================

set-default-shell:
	@case "$$SHELL" in \
		*/zsh) echo "zsh is already the default shell" ;; \
		*) \
			echo "Setting zsh as default shell..."; \
			ZSH_PATH=$$(which zsh); \
			if ! grep -qxF "$$ZSH_PATH" /etc/shells; then \
				echo "$$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null; \
			fi; \
			chsh -s "$$ZSH_PATH"; \
		;; \
	esac

# ============================================================
# Plugin check (platform-aware)
# ============================================================

check-plugins:
	@echo "Checking zsh plugin availability..."
	@missing=0; \
	if [ "$(OS)" = "Darwin" ]; then \
		BREW_PREFIX=$$(brew --prefix 2>/dev/null || echo "/opt/homebrew"); \
		if [ ! -f "$$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then \
			echo "  MISSING: zsh-autosuggestions"; missing=1; \
		else echo "  OK: zsh-autosuggestions"; fi; \
		if [ ! -f "$$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then \
			echo "  MISSING: zsh-syntax-highlighting"; missing=1; \
		else echo "  OK: zsh-syntax-highlighting"; fi; \
		for cmd in starship zoxide gls gdircolors uv ruff rustc cargo direnv; do \
			if command -v $$cmd > /dev/null 2>&1; then echo "  OK: $$cmd"; \
			else echo "  MISSING: $$cmd"; missing=1; fi; \
		done; \
	else \
		if [ ! -f "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then \
			echo "  MISSING: zsh-autosuggestions"; missing=1; \
		else echo "  OK: zsh-autosuggestions"; fi; \
		if [ ! -f "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then \
			echo "  MISSING: zsh-syntax-highlighting"; missing=1; \
		else echo "  OK: zsh-syntax-highlighting"; fi; \
		for cmd in starship zoxide ls dircolors uv ruff rustc cargo direnv; do \
			if command -v $$cmd > /dev/null 2>&1; then echo "  OK: $$cmd"; \
			else echo "  MISSING: $$cmd"; missing=1; fi; \
		done; \
	fi; \
	if [ $$missing -eq 1 ]; then \
		echo "Some plugins/tools are missing. Run 'make install' to install."; \
		exit 1; \
	else \
		echo "All plugins and tools are installed."; \
	fi

# ============================================================
# Tmux management
# ============================================================

set-tmux-plugins:
	@if [ -d $(HOME)/.config/tmux/plugins/tpm ]; then \
		echo "TPM already installed"; \
	else \
		mkdir -p $(HOME)/.config/tmux/plugins; \
		git clone https://github.com/tmux-plugins/tpm \
			$(HOME)/.config/tmux/plugins/tpm; \
		echo "TPM installed"; \
	fi
	@ln -sf $(DOTFILES_DIR)/tmux/.tmux.conf $(HOME)/.tmux.conf
	@$(BREW_ENV) tmux set-environment -g TMUX_PLUGIN_MANAGER_PATH $(HOME)/.config/tmux/plugins 2>/dev/null || \
		tmux start-server \; set-environment -g TMUX_PLUGIN_MANAGER_PATH $(HOME)/.config/tmux/plugins
	@$(BREW_ENV) $(HOME)/.config/tmux/plugins/tpm/bin/install_plugins

tmux-restart:
	@tmux kill-server 2>/dev/null; echo "tmux server killed"
	@echo "Run 'tmux' to start a new session"

tmux-reload:
	@tmux source-file ~/.tmux.conf 2>/dev/null && echo "tmux config reloaded" \
		|| echo "No tmux session running. Start tmux first"

# ============================================================
# Status & update
# ============================================================

status:
	@echo "=== Symlinks ==="
	@for f in ~/.zshrc ~/.config/starship.toml ~/.dircolors ~/.gitconfig ~/.tmux.conf ~/.local/bin/tmux-layout ~/.local/bin/tmux-rebalance-column ~/.local/bin/tmux-set-column-widths ~/.config/nvim ~/.config/ghostty/config ~/.config/puppeteer.json; do \
		if [ -L "$$f" ]; then echo "  OK: $$f -> $$(readlink $$f)"; \
		elif [ -e "$$f" ]; then echo "  WARN: $$f (not a symlink)"; \
		else echo "  MISSING: $$f"; fi; \
	done
	@echo ""
	@echo "=== Tool versions ==="
	@for cmd in zsh nvim starship zoxide uv ruff git node; do \
		if command -v $$cmd > /dev/null 2>&1; then \
			ver=$$($$cmd --version 2>/dev/null | head -1); \
			echo "  $$cmd: $$ver"; \
		else echo "  $$cmd: not installed"; fi; \
	done
	@if command -v tmux > /dev/null 2>&1; then \
		echo "  tmux: $$(tmux -V)"; \
	else echo "  tmux: not installed"; fi

update:
	@echo "Pulling latest dotfiles..."
	@git -C $(DOTFILES_DIR) pull --rebase
	@$(MAKE) link
	@echo "Update complete."

# ============================================================
# Cleanup
# ============================================================

clean:
ifeq ($(OS),Darwin)
	brew bundle cleanup --force --file=$(DOTFILES_DIR)/brewfiles/Brewfile
else
	@echo "clean: only available on macOS (brew bundle cleanup)"
endif

unlink:
	@echo "Removing symlinks..."
	@rm -f $(HOME)/.zshrc
	@rm -f $(HOME)/.config/starship.toml
	@rm -f $(HOME)/.dircolors
	@rm -f $(HOME)/.gitconfig
	@rm -f $(HOME)/.tmux.conf
	@rm -f $(HOME)/.local/bin/tmux-layout
	@rm -f $(HOME)/.local/bin/tmux-rebalance-column
	@rm -f $(HOME)/.local/bin/tmux-set-column-widths
	@rm -f $(HOME)/.config/nvim
	@rm -f $(HOME)/.config/ghostty/config
	@rm -f $(HOME)/.config/puppeteer.json

.PHONY: install install-nvchad install-others set-rust \
        set-xcode set-brew set-packages set-apt-packages set-neovim set-lazygit set-starship set-zoxide set-uv set-ruff set-golang set-go-packages set-nvchad-deps set-mermaid-cli set-hunk set-nvim-tools \
        link link-zshrc link-starship link-dircolors link-gitconfig link-tmux link-tmux-layout link-tmux-rebalance link-tmux-colwidths link-nvim link-ghostty link-puppeteer \
        set-default-shell check-plugins \
        set-tmux-plugins tmux-restart tmux-reload status update \
        clean unlink
