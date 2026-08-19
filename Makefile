.PHONY: help test lint format install-links upstream-log
.DEFAULT_GOAL := help

UPSTREAM_REPO := https://github.com/Muddyblack/kde-ai-usage.git
UPSTREAM_SHA  := $(shell awk '/^commit:/ {print $$2}' UPSTREAM)
PREFIX        ?= $(HOME)/.local

help: ## list targets
	@awk 'BEGIN{FS=":.*##"} /^[a-z][a-zA-Z0-9_-]+:.*##/ {printf "  make %-14s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

test: ## run every test (no network access needed)
	@./tests/get-ai-usage.test.sh
	@./tests/ai-usage-cli.test.sh
	@./tests/credentials.test.sh
	@./tests/python-interp.test.sh
	@./tests/get-codex-stats.test.sh
	@./tests/get-codex-rate-limits.test.sh

lint: ## lint + format-check (needs ruff)
	@if command -v ruff >/dev/null 2>&1; then ruff check aiusage && ruff format --check aiusage; \
	elif command -v uvx >/dev/null 2>&1; then uvx ruff check aiusage && uvx ruff format --check aiusage; \
	else echo "ruff not found — pip install ruff, or use uvx"; exit 1; fi

format: ## reformat with ruff
	@if command -v ruff >/dev/null 2>&1; then ruff format aiusage; \
	elif command -v uvx >/dev/null 2>&1; then uvx ruff format aiusage; \
	else echo "ruff not found"; exit 1; fi

install-links: ## symlink both tools into $(PREFIX)/bin (no copy, no pip)
	@mkdir -p "$(PREFIX)/bin"
	@ln -sfn "$(CURDIR)/bin/ai-usage-cli" "$(PREFIX)/bin/ai-usage-cli"
	@ln -sfn "$(CURDIR)/bin/get-ai-usage" "$(PREFIX)/bin/get-ai-usage"
	@echo "linked ai-usage-cli and get-ai-usage into $(PREFIX)/bin"
	@case ":$$PATH:" in *":$(PREFIX)/bin:"*) ;; \
	  *) echo "note: $(PREFIX)/bin is not on your PATH";; esac

upstream-log: ## what changed upstream, in the files this repo carries, since UPSTREAM
	@echo "base: $(UPSTREAM_SHA)"
	@tmp=$$(mktemp -d) && git -C "$$tmp" init -q && \
	  git -C "$$tmp" remote add origin $(UPSTREAM_REPO) && \
	  git -C "$$tmp" fetch -q --depth 200 origin master && \
	  echo && git -C "$$tmp" log --oneline $(UPSTREAM_SHA)..origin/master -- \
	    package/contents/tools/aiusage package/contents/tools/sh tests \
	  | sed 's/^/  /' && \
	  rm -rf "$$tmp"
	@echo
	@echo "(empty means nothing to pull; otherwise diff those paths against aiusage/, bin/, tests/)"
