#!/bin/bash
set -e

ROLE=$1 # primary, standby или witness

# Ждем, пока локальный Postgres поднимется
wait_for_pg() {
    until pg_isready -h localhost -U postgres > /dev/null 2>&1; do
        sleep 1
    done
}

# Генерируем repmgr.conf на лету из переменных окружения
cat <<EOF > /etc/repmgr.conf
node_id=$NODE_ID
node_name='$NODE_NAME'
conninfo='host=$NODE_NAME user=repmgr dbname=repmgr connect_timeout=2'
data_directory='/var/lib/postgresql/data'
failover='automatic'
promote_command='repmgr standby promote -f /etc/repmgr.conf --log-to-file'
follow_command='repmgr standby follow -f /etc/repmgr.conf --log-to-file --upstream-node-id=%n'
reconnect_attempts=3
reconnect_interval=5
EOF

if [ "$ROLE" = "primary" ]; then
    # Стартуем PG в фоне для инициализации
    docker-entrypoint.sh postgres &
    wait_for_pg

    # Создаем юзера и БД для repmgr
    psql -U postgres -c "CREATE ROLE repmgr WITH LOGIN SUPERUSER REPLICATION PASSWORD 'repmgr';" || true
    psql -U postgres -c "CREATE DATABASE repmgr OWNER repmgr;" || true
    
    # Регистрируем primary
    repmgr -f /etc/repmgr.conf primary register || true

    # Стартуем repmgrd (он будет держать контейнер живым)
    exec repmgrd -f /etc/repmgr.conf --daemonize=false

elif [ "$ROLE" = "standby" ]; then
    # Ждем, пока primary будет готов
    until pg_isready -h pg-primary -U repmgr -d repmgr > /dev/null 2>&1; do
        echo "Waiting for primary..."
        sleep 2
    done

    # Если еще не клонированы данные
    if [ ! -f /var/lib/postgresql/data/standby.signal ]; then
        # Останавливаем локальный PG, чтобы сделать clone
        pkill -f "postgres" || true
        sleep 2
        rm -rf /var/lib/postgresql/data/*
        
        # Клонируем данные с primary
        repmgr -h pg-primary -U repmgr -d repmgr -f /etc/repmgr.conf standby clone
    fi

    # Стартуем PG (уже как standby)
    docker-entrypoint.sh postgres &
    wait_for_pg

    # Регистрируем standby
    repmgr -f /etc/repmgr.conf standby register || true

    exec repmgrd -f /etc/repmgr.conf --daemonize=false

elif [ "$ROLE" = "witness" ]; then
    # Witness нужен только для кворума, данные с primary не клонирует
    docker-entrypoint.sh postgres &
    wait_for_pg

    psql -U postgres -c "CREATE ROLE repmgr WITH LOGIN SUPERUSER REPLICATION PASSWORD 'repmgr';" || true
    psql -U postgres -c "CREATE DATABASE repmgr OWNER repmgr;" || true

    # Ждем primary
    until pg_isready -h pg-primary -U repmgr -d repmgr > /dev/null 2>&1; do
        sleep 2
    done

    # Регистрируем witness
    repmgr -f /etc/repmgr.conf witness register -h pg-primary -U repmgr -d repmgr || true

    exec repmgrd -f /etc/repmgr.conf --daemonize=false
fi