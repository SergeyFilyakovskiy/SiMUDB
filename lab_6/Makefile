.PHONY: build up down clean status init failover lab shell logs help

COMPOSE := docker compose
PRIMARY := pg-primary
STANDBY := pg-standby
CLIENT  := app-client

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

build:
	$(COMPOSE) build

up:
	$(COMPOSE) up -d
	@echo "Ожидание инициализации сервисов..."
	@sleep 10

down:
	$(COMPOSE) down

clean:
	$(COMPOSE) down -v --remove-orphans
	@echo "Окружение полностью очищено."

status:
	$(COMPOSE) exec $(PRIMARY) repmgr -f /etc/repmgr.conf cluster show

init:
	@echo "Инициализация тестовых данных..."
	$(COMPOSE) exec -T $(PRIMARY) psql -U postgres -c "CREATE DATABASE appdb;" || true
	$(COMPOSE) exec -T $(PRIMARY) psql -U postgres -d appdb -c "CREATE TABLE IF NOT EXISTS users (id SERIAL PRIMARY KEY, name TEXT);"
	$(COMPOSE) exec -T $(PRIMARY) psql -U postgres -d appdb -c "INSERT INTO users (name) VALUES ('Alice'), ('Bob');"
	@echo "Данные успешно добавлены."

failover:
	@echo "========================================="
	@echo "=== НАЧАЛО ТЕСТА АВТОМАТИЧЕСКОГО FAILOVER ==="
	@echo "========================================="
	@START=$$(date +%s); \
	echo "[$$(date '+%H:%M:%S')] Имитация отказа: убиваем контейнер primary..."; \
	docker rm -f $(PRIMARY) > /dev/null 2>&1; \
	echo "[$$(date '+%H:%M:%S')] Ожидание переключения на standby..."; \
	until $(COMPOSE) exec -T $(CLIENT) psql -h $(STANDBY) -U postgres -d appdb -c "INSERT INTO users(name) VALUES('failover_test');" 2>&1 | grep -q "INSERT 0 1"; do \
		echo "  -> Standby еще в режиме read-only, ждем..."; \
		sleep 1; \
	done; \
	END=$$(date +%s); \
	DURATION=$$((END - START)); \
	echo "========================================="; \
	echo "[$$(date '+%H:%M:%S')] FAILOVER ЗАВЕРШЕН!"; \
	echo "Время восстановления (RTO): $$DURATION секунд"; \
	echo "========================================="; \
	echo ""; \
	echo "=== ПРОВЕРКА ДОСТУПНОСТИ ПРИЛОЖЕНИЯ ==="; \
	$(COMPOSE) exec -T $(CLIENT) psql -h $(STANDBY) -U postgres -d appdb -c "SELECT * FROM users;"

shell: 
	$(COMPOSE) exec $(CLIENT) bash

logs: 
	$(COMPOSE) logs -f

lab:
	@echo ">>> Шаг 1: Очистка старого окружения..."
	@$(MAKE) clean
	@echo ">>> Шаг 2: Сборка и запуск..."
	@$(MAKE) build
	@$(MAKE) up
	@echo ">>> Шаг 3: Проверка статуса кластера..."
	@$(MAKE) status
	@echo ">>> Шаг 4: Инициализация данных..."
	@$(MAKE) init
	@echo ">>> Шаг 5: Запуск теста failover..."
	@$(MAKE) failover
	@echo ""
	