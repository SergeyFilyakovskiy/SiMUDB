.PHONY: up down logs shell seed clean

COMPOSE_FILE := docker-compose.yml

up:
	docker compose -f $(COMPOSE_FILE) up -d

down:
	docker compose -f $(COMPOSE_FILE) down

logs:
	docker compose -f $(COMPOSE_FILE) logs -f postgres

shell:
	docker compose -f $(COMPOSE_FILE) exec -it postgres psql -U postgres -W 12345678 -d ApplicationDatabase

# Запуск генерации данных
seed:
	docker compose -f $(COMPOSE_FILE) exec -T postgres psql -U postgres -W 12345678 -d ApplicationDatabase < seed.sql

# Полный сброс + перегенерация
reset:
	make down
	make up
	sleep 5
	make seed

clean:
	docker compose -f $(COMPOSE_FILE) down -v