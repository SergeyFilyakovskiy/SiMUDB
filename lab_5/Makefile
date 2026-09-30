.PHONY: help up down restart logs clean shell seed analyze status sizes

DOCKER_COMPOSE := docker compose
CONTAINER_NAME := clickhouse-lab
INIT_DIR       := ./clickhouse
SCRIPTS_DIR    := ./scripts

ifneq (,$(wildcard ./.env))
    include .env
    export
endif

CH_USER     ?= $(CLICKHOUSE_USER)
CH_PASSWORD ?= $(CLICKHOUSE_PASSWORD)
CH_DB       ?= $(CLICKHOUSE_DB)

help:
	@echo ""
	@echo "Доступные команды:"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""

up:
	@echo "Запуск ClickHouse..."
	$(DOCKER_COMPOSE) up -d
	@echo "Контейнер запущен. Ожидаем готовности..."
	@$(MAKE) wait-ready
	@echo "Данные автоматически генерируются через 02-seed.sql..."

down:
	$(DOCKER_COMPOSE) down

restart: down up

logs:
	$(DOCKER_COMPOSE) logs -f $(CONTAINER_NAME)

status:
	@docker inspect --format='{{.State.Health.Status}}' $(CONTAINER_NAME) 2>/dev/null || echo "Контейнер не запущен"
	$(DOCKER_COMPOSE) ps

shell:
	docker exec -it $(CONTAINER_NAME) \
		clickhouse-client \
			--user="$(CH_USER)" \
			--password="$(CH_PASSWORD)" \
			--database="$(CH_DB)" \
			--multiline

seed:
	@echo "Выполняется seed.sql..."
	@$(MAKE) wait-ready
	docker exec -i $(CONTAINER_NAME) \
		clickhouse-client \
			--user="$(CH_USER)" \
			--password="$(CH_PASSWORD)" \
			--database="$(CH_DB)" \
			--multiquery \
		< $(INIT_DIR)/02-seed.sql
	@echo "Данные успешно сгенерированы"

analyze:
	@echo "Выполняется analyze.sql..."
	@$(MAKE) wait-ready
	docker exec -i $(CONTAINER_NAME) \
		clickhouse-client \
			--user="$(CH_USER)" \
			--password="$(CH_PASSWORD)" \
			--database="$(CH_DB)" \
			--multiquery \
			--time \
		< $(SCRIPTS_DIR)/analyze.sql
	@echo "Анализ завершён"

clean: down
	@echo "Удаляем volumes с данными..."
	$(DOCKER_COMPOSE) down -v --remove-orphans
	@echo "Очистка завершена"

wait-ready:
	@echo "Ожидание готовности ClickHouse..."
	@timeout=120; \
	elapsed=0; \
	while [ $$elapsed -lt $$timeout ]; do \
		status=$$(docker inspect --format='{{.State.Health.Status}}' $(CONTAINER_NAME) 2>/dev/null || echo "missing"); \
		if [ "$$status" = "healthy" ]; then \
			echo "ClickHouse готов к работе ($$elapsed сек)"; \
			exit 0; \
		fi; \
		sleep 2; \
		elapsed=$$((elapsed + 2)); \
		printf "."; \
	done; \
	echo ""; \
	echo "Таймаут ожидания. Проверьте логи: make logs"; \
	exit 1

sizes: ## Показать размеры таблиц
	@$(MAKE) wait-ready
	@docker exec -i $(CONTAINER_NAME) \
		clickhouse-client \
			--user="$(CH_USER)" \
			--password="$(CH_PASSWORD)" \
			--database="$(CH_DB)" \
		--query="SELECT table_name, formatReadableSize(total_bytes) AS size, total_rows, partition_count FROM table_sizes_compare ORDER BY total_bytes"