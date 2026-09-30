FROM postgres:16-bookworm

# Устанавливаем repmgr из официального репозитория PGDG, который уже есть в образе
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-16-repmgr \
    sudo \
    procps \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]