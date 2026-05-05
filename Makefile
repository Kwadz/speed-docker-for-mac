.DEFAULT_GOAL := help

UNAME := $(shell uname -s)
ifeq ($(UNAME),Darwin)
    COMPOSE ?= mutagen-compose -f compose.yaml -f compose.mac.yaml
else
    COMPOSE ?= docker compose
endif
export COMPOSE_CMD := $(COMPOSE)

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

.PHONY: up
up: ## Start the stack (auto-selects Mutagen on Mac)
	$(COMPOSE) up -d --build

.PHONY: down
down: ## Stop the stack
	$(COMPOSE) down

.PHONY: clean
clean: ## Stop and wipe volumes
	$(COMPOSE) down -v

.PHONY: logs
logs: ## Tail logs
	$(COMPOSE) logs -f

.PHONY: ps
ps: ## Show running services
	$(COMPOSE) ps

.PHONY: sh
sh: ## Shell into the php-fpm container
	$(COMPOSE) exec php-fpm sh

.PHONY: install
install: ## composer install + migrations + fixtures
	$(COMPOSE) exec php-fpm composer install --no-interaction
	$(COMPOSE) exec php-fpm bin/console doctrine:migrations:migrate --no-interaction
	$(COMPOSE) exec php-fpm bin/console doctrine:fixtures:load --no-interaction

.PHONY: sync-status
sync-status: ## Show Mutagen sync sessions (Mac only)
	@if [ "$(UNAME)" = "Darwin" ]; then mutagen sync list; else echo "Linux: native bind mount, no sync session needed."; fi

.PHONY: check-sync
check-sync: ## Verify file sync works both directions
	@./scripts/check-sync.sh

.PHONY: bench
bench: ## Run filesystem performance benchmark
	@./scripts/benchmark.sh
