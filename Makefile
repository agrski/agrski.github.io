SHELL := /usr/bin/env bash -o pipefail -o noclobber

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo Available commands:
	@sed -rn '/^[a-zA-Z0-9_-]+:/ {s/:.*//; s/^/  /; p}' $(MAKEFILE_LIST)

.draft_dir := docs/_drafts
.post_suffix := .md
.diagram_suffix := .mmd
.image_suffix := .png
f ?= $(error file name f must be set)

.PHONY: draft
draft:
	@echo -e '---\ntitle: \ntags: \n---\n\n' > $(.draft_dir)/$(f)$(.post_suffix)

.PHONY: flowchart
flowchart:
	@cp .flowchart.mmd.tmpl $(.draft_dir)/$(f)$(.diagram_suffix)

%$(.image_suffix): %$(.diagram_suffix)
	@mmdc -i $< -o $@
	@convert $@ -pointsize 12 -fill grey50 label:"Copyright (C) agrski $$(date +%Y)" -gravity center -append $@

.diagrams := $(wildcard $(.draft_dir)/*$(.diagram_suffix))
.images := $(.diagrams:$(.diagram_suffix)=$(.image_suffix))

.PHONY: images
images: $(.images)
