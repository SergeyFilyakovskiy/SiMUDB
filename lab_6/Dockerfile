FROM postgres:16-alpine

# Ставим зависимости для компиляции
RUN apk add --no-cache build-base postgresql-dev libxml2-dev openssl-dev pam-dev readline-dev zlib-dev curl

# Качаем и собираем repmgr (версия 5.4.1 поддерживает PG 16)
RUN curl -sL https://github.com/EnterpriseDB/repmgr/archive/refs/tags/v5.4.1.tar.gz | tar xz -C /tmp && \
    cd /tmp/repmgr-5.4.1 && \
    ./configure --prefix=/usr && \
    make && \
    make install && \
    rm -rf /tmp/repmgr-5.4.1

# Копируем наш кастомный entrypoint
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]