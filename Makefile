PYTHON ?= python3
VENV ?= .venv
IMAGE ?= jupyter:test

help: ## Display available targets
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_-]+:.*## / {printf "\033[36m%-28s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

development-requirements: ## Install development tools in a virtual environment
	$(PYTHON) -m venv $(VENV)
	$(VENV)/bin/python -m pip install -r requirements-dev.txt

lint: ## Check Python style and Compose configuration
	$(VENV)/bin/ruff check .
	$(VENV)/bin/ruff format --check .
	docker compose config --quiet

pre-commit-install: ## Install local Git pre-commit hooks
	$(VENV)/bin/pre-commit install

pre-commit-run: ## Run pre-commit checks on all tracked files
	$(VENV)/bin/pre-commit run --all-files

build: ## Build the local image
	docker build -t $(IMAGE) .

test: build ## Build and run container integration tests
	JUPYTER_TEST_IMAGE=$(IMAGE) $(VENV)/bin/python -m unittest discover -s tests -v

.PHONY: help development-requirements lint pre-commit-install pre-commit-run build test
