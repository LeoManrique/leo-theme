# Makefile — 18 of these in your tree.
#
# No numeric prefix: make finds this file by exact name, and `19-Makefile`
# would not be detected as a makefile by either editor.
#
# Makefiles are the one place where a literal tab is syntax. Every recipe line
# below starts with a real tab, not spaces — if your editor shows them as
# spaces, renderWhitespace is off, not broken.

.DEFAULT_GOAL := help
.DELETE_ON_ERROR:
.SUFFIXES:

SHELL      := /bin/bash
.SHELLFLAGS := -euo pipefail -c

# ── Variables: the four assignment operators ──────────────────────────────

NAME        = preview
VERSION    := 1.0.2
CC         ?= cc
CFLAGS     := -std=c11 -Wall -Wextra -O2
LDFLAGS    +=
PREFIX     ?= /usr/local
BUILD_DIR  := build
GIT_SHA    := $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)
DATE       := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)

C_SOURCES  := $(wildcard *.c)
C_OBJECTS  := $(patsubst %.c,$(BUILD_DIR)/%.o,$(C_SOURCES))
SAMPLES    := $(sort $(wildcard [0-9][0-9]-*))

# Conditional assignment based on platform.
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	PLATFORM := macos
	CFLAGS   += -mmacosx-version-min=13.0
else ifeq ($(UNAME_S),Linux)
	PLATFORM := linux
else
	PLATFORM := unknown
endif

ifdef VERBOSE
	Q :=
else
	Q := @
endif

# ── Targets ───────────────────────────────────────────────────────────────

.PHONY: help all check clean install uninstall list
.SILENT: help

help: ## Show this help
	echo "$(NAME) $(VERSION) ($(PLATFORM), $(GIT_SHA))"
	echo
	grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

all: $(BUILD_DIR)/$(NAME) ## Build everything

$(BUILD_DIR):
	$(Q)mkdir -p $@

# Pattern rule with automatic variables: $@ target, $< first prereq, $^ all.
$(BUILD_DIR)/%.o: %.c | $(BUILD_DIR)
	@echo "  CC      $<"
	$(Q)$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/$(NAME): $(C_OBJECTS)
	@echo "  LINK    $@"
	$(Q)$(CC) $(LDFLAGS) $^ -o $@

check: ## Verify every sample still parses
	@echo "  CHECK   go"
	$(Q)cd go && go vet ./...
	@echo "  CHECK   rust"
	$(Q)cd rust && cargo check --quiet
	@echo "  CHECK   c"
	$(Q)$(CC) $(CFLAGS) -fsyntax-only 05-decomp.c
	@echo "  CHECK   python"
	$(Q)python3 -c "import ast; ast.parse(open('16-script.py').read())"
	@echo "  CHECK   json"
	$(Q)python3 -m json.tool 09-config.json > /dev/null
	@echo "  CHECK   shell"
	$(Q)bash -n 11-script.sh
	@echo "  CHECK   just"
	$(Q)command -v just >/dev/null && just --summary >/dev/null || echo "    (just not installed, skipped)"
	@echo "  CHECK   zig"
	$(Q)command -v zig >/dev/null && zig ast-check 17-main.zig || echo "    (zig not installed, skipped)"
	@echo "  all samples parse"

list: ## List the numbered samples
	$(Q)for f in $(SAMPLES); do \
		printf '  %-24s %s\n' "$$f" "$$(wc -l < $$f | tr -d ' ') lines"; \
	done

clean: ## Remove build output
	$(Q)$(RM) -r $(BUILD_DIR) go/preview rust/target
	@echo "  cleaned"

install: all ## Install into $(PREFIX)/bin
	$(Q)install -d $(DESTDIR)$(PREFIX)/bin
	$(Q)install -m 0755 $(BUILD_DIR)/$(NAME) $(DESTDIR)$(PREFIX)/bin/$(NAME)

uninstall: ## Remove from $(PREFIX)/bin
	$(Q)$(RM) $(DESTDIR)$(PREFIX)/bin/$(NAME)

-include local.mk
