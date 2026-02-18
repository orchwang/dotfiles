SHELL := /bin/bash
DOTFILES_DIR := $(shell pwd)
OS := $(shell uname -s)

# ============================================================
# Primary targets
# ============================================================

ifeq ($(OS),Darwin)
install: set-xcode set-brew set-packages set-rust link set-default-shell
	@echo "Installation complete. Restart your shell or run: source ~/.zshrc"
else
install: set-apt-packages set-neovim set-starship set-zoxide set-uv set-ruff set-rust link set-default-shell
	@echo "Installation complete. Restart your shell or run: source ~/.zshrc"
endif

# ============================================================
# macOS prerequisites
# ============================================================

set-xcode:
ifeq ($(OS),Darwin)
	@if xcode-select -p > /dev/null 2>&1; then \
		echo "Xcode command line tools already installed"; \
	else \
		xcode-select --install; \
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
	brew update
	brew bundle --file=$(DOTFILES_DIR)/brewfiles/Brewfile
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
ifneq ($(OS),Darwin)
	@if command -v nvim > /dev/null 2>&1 && nvim --version | head -1 | grep -qE 'v0\.(9|[1-9][0-9])'; then \
		echo "Neovim >= 0.9 already installed"; \
	else \
		echo "Installing Neovim stable via tarball..."; \
		curl -Lo /tmp/nvim-linux-x86_64.tar.gz https://github.com/neovim/neovim/releases/download/stable/nvim-linux-x86_64.tar.gz; \
		tar -xzf /tmp/nvim-linux-x86_64.tar.gz -C /tmp; \
		mkdir -p $(HOME)/.local; \
		cp -r /tmp/nvim-linux-x86_64/* $(HOME)/.local/; \
		rm -rf /tmp/nvim-linux-x86_64 /tmp/nvim-linux-x86_64.tar.gz; \
		echo "Neovim installed to ~/.local/bin/nvim"; \
	fi
else
	@echo "On macOS, neovim is installed via brew"
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

install-others:
ifeq ($(OS),Darwin)
	brew update
	brew bundle --file=$(DOTFILES_DIR)/brewfiles/BrewFile.others
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

# ============================================================
# Symlinks
# ============================================================

link: link-zshrc link-starship link-dircolors link-gitconfig link-tmux link-nvim link-ghostty
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
		for cmd in starship zoxide gls gdircolors uv ruff rustc cargo; do \
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
		for cmd in starship zoxide ls dircolors uv ruff rustc cargo; do \
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
	@for f in ~/.zshrc ~/.config/starship.toml ~/.dircolors ~/.gitconfig ~/.tmux.conf ~/.config/nvim ~/.config/ghostty/config; do \
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
	@rm -f $(HOME)/.config/nvim
	@rm -f $(HOME)/.config/ghostty/config

.PHONY: install install-others set-rust \
        set-xcode set-brew set-packages set-apt-packages set-neovim set-starship set-zoxide set-uv set-ruff \
        link link-zshrc link-starship link-dircolors link-gitconfig link-tmux link-nvim link-ghostty \
        set-default-shell check-plugins \
        tmux-restart tmux-reload status update \
        clean unlink
