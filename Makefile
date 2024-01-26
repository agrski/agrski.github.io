SHELL := /usr/bin/env bash -o pipefail -o noclobber

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo Available commands:
	@sed -rn '/^[a-zA-Z0-9_-]+:/ {s/:.*//; s/^/  /; p}' $(MAKEFILE_LIST)

.draft_dir := docs/_drafts/
.post_suffix := .md
f ?= $(error file name f must be set)

draft:
	@echo -e '---\ntitle: \ntags: \n---\n\n' > $(.draft_dir)/$(f)$(.post_suffix)

flowchart:
	@echo flowchart
