PYTHON ?= python3
VENV ?= .venv
IMAGE ?= jupyter:test

help: ## Display available targets
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_-]+:.*## / {printf "\033[36m%-28s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

all: development-requirements lint pre-commit-install build up open ## Everything

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

up: ## Start all containers in detached mode
	docker compose up --detach

open: ## Open Jupyter in the browser
	@echo
	@echo "jupyter: $(JUPYTER_URL)"
	@echo "   logs: make logs"
	@open "$(JUPYTER_URL)"

test: build ## Build and run container integration tests
	$(MAKE) test-image

test-image: ## Run integration tests against an existing image
	JUPYTER_TEST_IMAGE=$(IMAGE) $(VENV)/bin/python -m unittest discover -s tests -v

down: ## Stop all containers
	-docker compose down

logs: ## Tail container logs
	-docker compose logs -f

status: ## Show running container status
	-@docker compose ps --format 'table {{.Service}}\t{{.Status}}'

clean: clean-docker clean-notebooks clean-jupyter ## Remove all containers, volumes, and temp files

_clean-docker: # Remove containers, volumes, and orphan networks
	-docker compose down -v --remove-orphans

_clean-notebooks: # Strip outputs from all .ipynb files
	find . -name '*.ipynb' -not -path './.git/*' -exec nbstripout {} +

_clean-jupyter: # Remove Jupyter checkpoints and trash dirs
	-find . -type d -name .ipynb_checkpoints -exec rm -rvf \{\} \;
	-find . -type d -name .Trash\* -exec rm -rvf \{\} \;

.PHONY: help all development-requirements lint pre-commit-install pre-commit-run build up open test test-image down logs status clean clean-docker clean-notebooks clean-jupyter
