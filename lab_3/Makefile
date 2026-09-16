.PHONY: up down logs shell clean reset analyze

COMPOSE_FILE := docker-compose.yml

up:
	docker compose -f $(COMPOSE_FILE) up -d

down:
	docker compose -f $(COMPOSE_FILE) down

logs:
	docker compose -f $(COMPOSE_FILE) logs -f postgres

shell:
	docker compose -f $(COMPOSE_FILE) exec -it postgres psql -U postgres -d task_queue_db

# Запуск анализа
analyze:
	docker compose -f $(COMPOSE_FILE) exec -T postgres psql -U postgres -d task_queue_db < analyze.sql

# Сохранение результатов в файл
report:
	docker compose -f $(COMPOSE_FILE) exec -T postgres psql -U postgres -d task_queue_db < analyze.sql > report.txt

# Полный сброс и перезапуск
reset:
	make down
	make clean
	make up
	sleep 5

clean:
	docker compose -f $(COMPOSE_FILE) down -v