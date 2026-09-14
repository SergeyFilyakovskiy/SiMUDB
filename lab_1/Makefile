.PHONY: up down logs shell clean

COMPOSE_FILE := docker-compose.yml

# Запуск контейнеров в фоне
up:
	docker compose -f $(COMPOSE_FILE) up -d

# Остановка контейнеров
down:
	docker compose -f $(COMPOSE_FILE) down

# Просмотр логов (здесь будет вывод нашего init-mongo.js)
logs:
	docker compose -f $(COMPOSE_FILE) logs -f mongodb

# Зайти внутрь контейнера в интерактивную консоль mongosh
shell:
	docker compose -f $(COMPOSE_FILE) exec -it mongodb mongosh task_db

# Полная очистка (остановка + удаление томов с данными)
# Нужно использовать, если вы изменили init-mongo.js и хотите прогнать его заново
clean:
	docker compose -f $(COMPOSE_FILE) down -v