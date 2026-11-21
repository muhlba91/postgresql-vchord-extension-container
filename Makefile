CONTAINER_ENGINE ?= docker
POSTGRESQL_MAJOR_VERSION := $(shell grep -m 1 'ARG POSTGRESQL_MAJOR_VERSION' Dockerfile | cut -d'=' -f2)
POSTGRESQL_IMAGE ?= ghcr.io/cloudnative-pg/postgresql:$(POSTGRESQL_MAJOR_VERSION)-minimal-trixie
PGVECTOR_IMAGE := $(shell grep -m 1 'pgvector_image:' .github/workflows/verify.yml | awk '{print $$2}')
VCHORD_VERSION := $(shell grep -m 1 'ARG VCHORD_VERSION' Dockerfile | cut -d'=' -f2)

.PHONY: help check lint test
.DEFAULT_GOAL := help

help: ## show the available targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "%-8s %s\n", $$1, $$2}'

check: lint test ## run all gates

lint: ## lint the Dockerfile, shell, YAML and Markdown files
	hadolint Dockerfile
	shellcheck test/smoke.sh
	gitleaks git
	yamllint .
	markdownlint-cli2 "**/*.md"

test: ## build the image for the host platform and run the smoke test
	$(CONTAINER_ENGINE) build -t vchord-extension:test --build-arg VCHORD_VERSION=$(VCHORD_VERSION) .
	CONTAINER_ENGINE=$(CONTAINER_ENGINE) test/smoke.sh $(POSTGRESQL_IMAGE) $(PGVECTOR_IMAGE) vchord-extension:test $(VCHORD_VERSION)
