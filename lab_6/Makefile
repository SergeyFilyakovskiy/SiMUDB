.PHONY: up down clean status init failover lab logs help build

COMPOSE := docker compose
PRIMARY := pg-primary
STANDBY := pg-standby
CLIENT  := app-client
REPMGR_CONF := /etc/repmgr.conf  # Правильный путь для нашего образа!

help: ## Показать справку
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

build: ## Собрать образы без кэша
	$(COMPOSE) build --no-cache

up: ## Поднять кластер
	$(COMPOSE) up -d
	@echo "Ожидание инициализации кластера (около 30 секунд)..."
	@sleep 30

down: ## Остановить
	$(COMPOSE) down

clean: ## Полная очистка
	$(COMPOSE) down -v --remove-orphans

status: ## Статус repmgr (запускаем через gosu от пользователя postgres)
	$(COMPOSE) exec $(PRIMARY) bash -c "gosu postgres repmgr -f $(REPMGR_CONF) cluster show"

init: ## Создать тестовые данные
	@echo "Инициализация БД..."
	$(COMPOSE) exec -T $(PRIMARY) bash -c "gosu postgres psql -U postgres -c 'CREATE DATABASE appdb;'" || true
	$(COMPOSE) exec -T $(PRIMARY) bash -c "gosu postgres psql -U postgres -d appdb -c 'CREATE TABLE IF NOT EXISTS users (id SERIAL PRIMARY KEY, name TEXT);'"
	$(COMPOSE) exec -T $(PRIMARY) bash -c "gosu postgres psql -U postgres -d appdb -c \"INSERT INTO users (name) VALUES ('Alice'), ('Bob');\""

failover: ## Тест Failover
	@echo "========================================="
	@echo "=== НАЧАЛО ТЕСТА FAILOVER ==="
	@echo "========================================="
	@START=$$(date +%s); \
	echo "[$$(date '+%H:%M:%S')] Убиваем primary..."; \
	docker rm -f $(PRIMARY) > /dev/null 2>&1; \
	echo "[$$(date '+%H:%M:%S')] Ожидание promote на standby..."; \
	until $(COMPOSE) exec -T $(CLIENT) psql -h $(STANDBY) -U postgres -d appdb -c "INSERT INTO users(name) VALUES('failover_test');" 2>&1 | grep -q "INSERT 0 1"; do \
		sleep 1; \
	done; \
	END=$$(date +%s); \
	DURATION=$$((END - START)); \
	echo "[$$(date '+%H:%M:%S')] FAILOVER ЗАВЕРШЕН! Время (RTO): $$DURATION секунд"; \
	echo "========================================="; \
	$(COMPOSE) exec -T $(CLIENT) psql -h $(STANDBY) -U postgres -d appdb -c "SELECT * FROM users;"

lab:
	@$(MAKE) clean
	@$(MAKE) build
	@$(MAKE) up
	@$(MAKE) status
	@$(MAKE) init
	@$(MAKE) failover