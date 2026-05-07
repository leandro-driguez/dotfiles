# Convenience wrappers around bootstrap.sh and scripts/*.sh.
# All targets are .PHONY (no real files produced under their names).

REPO_ROOT := $(shell pwd)
BOOTSTRAP := $(REPO_ROOT)/bootstrap.sh

.PHONY: help install stow pkgs services system templates export uninstall lint dry-run

help:
	@echo "Targets:"
	@echo "  make install      Full bootstrap (./bootstrap.sh --yes)"
	@echo "  make dry-run      Preview bootstrap without changing anything"
	@echo "  make stow         Only re-link Stow packages"
	@echo "  make pkgs         Only re-install packages (pacman + AUR)"
	@echo "  make services     Only re-enable systemd services"
	@echo "  make system       Only apply system/etc/* to /etc/"
	@echo "  make templates    Only re-render *.tmpl files"
	@echo "  make export       Regenerate packages/*.txt and services-*.txt"
	@echo "  make uninstall    Stow -D every package (does not remove pkgs)"
	@echo "  make lint         shellcheck on all *.sh"

install:
	$(BOOTSTRAP) --yes

dry-run:
	$(BOOTSTRAP) --dry-run

stow:
	$(BOOTSTRAP) --only=stow

pkgs:
	$(BOOTSTRAP) --only=official-pkgs

services:
	$(BOOTSTRAP) --only=services-system
	$(BOOTSTRAP) --only=services-user

system:
	$(BOOTSTRAP) --only=system-files

templates:
	$(BOOTSTRAP) --only=render-templates

export:
	$(REPO_ROOT)/scripts/export-state.sh

uninstall:
	@for pkg in $$(ls -d */ | sed 's,/$$,,' | grep -vE '^(docs|env|packages|scripts|system|legacy)$$'); do \
		echo "Unstowing $$pkg..."; \
		stow -D -v -t $$HOME -d $(REPO_ROOT) $$pkg || true; \
	done

lint:
	$(REPO_ROOT)/scripts/lint.sh
