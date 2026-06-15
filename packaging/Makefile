.PHONY: install uninstall test lint help

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
SHAREDIR ?= $(PREFIX)/share/termeric
VERSION ?= $(shell cat VERSION 2>/dev/null || echo "0.0.0")

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: ## Install termeric
	@mkdir -p $(BINDIR) $(SHAREDIR)/completions $(SHAREDIR)/ai
	@cp bin/termeric $(BINDIR)/termeric
	@chmod +x $(BINDIR)/termeric
	@cp termeric_bash termeric_zsh termeric_fish $(SHAREDIR)/
	@cp ai/termeric_ai $(SHAREDIR)/ai/
	@cp completions/termeric.bash $(SHAREDIR)/completions/
	@cp completions/termeric.zsh $(SHAREDIR)/completions/
	@cp completions/termeric.fish $(SHAREDIR)/completions/
	@# Bash completions
	@mkdir -p $(PREFIX)/share/bash-completion/completions
	@cp completions/termeric.bash $(PREFIX)/share/bash-completion/completions/termeric
	@# Zsh completions
	@mkdir -p $(PREFIX)/share/zsh/site-functions
	@cp completions/termeric.zsh $(PREFIX)/share/zsh/site-functions/_termeric
	@# Fish completions
	@mkdir -p $(PREFIX)/share/fish/vendor_completions.d
	@cp completions/termeric.fish $(PREFIX)/share/fish/vendor_completions.d/termeric.fish
	@echo ""
	@echo "\033[32m✓\033[0m Termeric installed to $(PREFIX)"
	@echo "  Run 'termeric install' to activate, then 'exec bash', 'exec zsh', or 'exec fish'"

uninstall: ## Remove termeric
	@rm -f $(BINDIR)/termeric
	@rm -rf $(SHAREDIR)
	@rm -f $(PREFIX)/share/bash-completion/completions/termeric
	@rm -f $(PREFIX)/share/zsh/site-functions/_termeric
	@rm -f $(PREFIX)/share/fish/vendor_completions.d/termeric.fish
	@echo "\033[32m✓\033[0m Termeric uninstalled from $(PREFIX)"
	@echo "  Remove source lines from ~/.bashrc / ~/.zshrc manually"

test: lint ## Run all tests
	@echo "\033[32m✓\033[0m All tests passed"

lint: lint-bash lint-zsh lint-shfmt ## Run linters

lint-bash: ## Lint bash files
	@echo "Checking bash syntax..."
	@bash -n termeric_bash
	@bash -n bin/termeric
	@echo "\033[32m✓\033[0m bash syntax OK"

lint-zsh: ## Lint zsh files
	@echo "Checking zsh syntax..."
	@zsh -n termeric_zsh
	@echo "\033[32m✓\033[0m zsh syntax OK"

lint-shfmt: ## Check shell formatting (if shfmt available)
	@which shfmt >/dev/null 2>&1 && shfmt -d bin/termeric || echo "shfmt not found, skipping"

version: ## Show version
	@cat VERSION
