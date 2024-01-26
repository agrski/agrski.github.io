SHELL := /usr/bin/env bash -o pipefail

.PHONY: help
help:
	@echo Available commands:
	@sed -rn '/^[a-zA-Z0-9_-]+:/ {s/:.*//; s/^/  /; p}' $(MAKEFILE_LIST)

draft:
	@echo hello

flowchart:
	@echo world
