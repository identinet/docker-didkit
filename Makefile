#!/usr/bin/env make -f
.POSIX:
.SUFFIXES:

PREFIX = /usr/local
DESTDIR =

.PHONY: help
help: ## Show this help (default)
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: all
all: ## Do everything

.PHONY: build
build: ## Build docker image
	docker build . -t didkit:latest

.PHONY: clean
clean: ## Cleanup the build
	@rm -vf game graphics.o physics.o input.o
