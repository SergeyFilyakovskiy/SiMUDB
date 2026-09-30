#!/bin/bash
set -e

ROLE=${ROLE:-$1}
PG_DATA="/var/lib/postgresql/data"

# 1. Конфиг для repmgr
cat <<EOF > /etc/repmgr.conf
node_id=$NODE_ID
node_name='$NODE_NAME'
conninfo='host=$NODE_NAME user=repmgr dbname=repmgr connect_timeout=2'
data_directory='$PG_DATA'
failover='automatic'
promote_command='repmgr standby promote -f /etc/repmgr.conf --log-to-file'
follow_command='repmgr standby follow -f /etc/repmgr.conf --log-to-file --upstream-node-id=%n'
reconnect_attempts=3
reconnect_interval=5
EOF

# 2. Инициализация базы, если она пустая
if [ ! -s "$PG_DATA/PG_VERSION" ]; then
    echo "Инициализация базы данных..."
    chown -R postgres:postgres "$PG_DATA"
    chmod 700 "$PG_DATA"
    gosu postgres initdb -D "$PG_DATA"
fi

# 3. Настройка postgresql.conf (добавлен wal_log_hints = on)
if ! grep -q "shared_preload_libraries = 'repmgr'" "$PG_DATA/postgresql.conf"; then
    cat <<EOF >> "$PG_DATA/postgresql.conf"
listen_addresses = '*'
shared_preload_libraries = 'repmgr'
wal_level = replica
wal_log_hints = on
max_wal_senders = 10
wal_keep_size = 256MB
hot_standby = on
EOF
fi

# 4. Настройка pg_hba.conf
cat <<EOF > "$PG_DATA/pg_hba.conf"
local   all             all                                     trust
host    all             all             127.0.0.1/32            trust
host    all             all             ::1/128                 trust
host    replication     repmgr          0.0.0.0/0               trust
host    repmgr          repmgr          0.0.0.0/0               trust
host    all             all             0.0.0.0/0               trust
EOF
chown postgres:postgres "$PG_DATA/pg_hba.conf"

wait_for_pg() {
    until pg_isready -h localhost -U postgres > /dev/null 2>&1; do
        sleep 1
    done
}

if [ "$ROLE" = "primary" ]; then
    gosu postgres postgres -D "$PG_DATA" &
    wait_for_pg

    gosu postgres psql -U postgres -c "ALTER USER postgres PASSWORD 'postgres';" || true
    gosu postgres psql -U postgres -c "CREATE ROLE repmgr WITH LOGIN SUPERUSER REPLICATION PASSWORD 'repmgr';" || true
    gosu postgres psql -U postgres -c "CREATE DATABASE repmgr OWNER repmgr;" || true
    
    gosu postgres repmgr -f /etc/repmgr.conf primary register || true
    gosu postgres repmgrd -f /etc/repmgr.conf --daemonize=false &
    
    wait -n
    echo "Postgres or repmgrd died"
    exit 1

elif [ "$ROLE" = "standby" ]; then
    # Ждем, пока сервер на pg-primary просто поднимется
    until pg_isready -h pg-primary -U postgres > /dev/null 2>&1; do
        echo "Waiting for primary server..."
        sleep 2
    done

    # Дополнительная пауза, чтобы первичный успел создать пользователя
    echo "Primary is up, waiting 5s for users to be created..."
    sleep 5

    if [ ! -f "$PG_DATA/standby.signal" ]; then
        gosu postgres pg_ctl stop -m fast -D "$PG_DATA" || true
        sleep 2
        rm -rf "$PG_DATA"/*
        # ДОБАВЛЕН --fast-checkpoint! Теперь клонирование не будет ждать 5 минут
        gosu postgres repmgr -h pg-primary -U repmgr -d repmgr -f /etc/repmgr.conf standby clone --force --fast-checkpoint --verbose
    fi

    gosu postgres postgres -D "$PG_DATA" &
    wait_for_pg
    
    gosu postgres repmgr -f /etc/repmgr.conf standby register || true
    gosu postgres repmgrd -f /etc/repmgr.conf --daemonize=false &
    
    wait -n
    exit 1

elif [ "$ROLE" = "witness" ]; then
    gosu postgres postgres -D "$PG_DATA" &
    wait_for_pg

    gosu postgres psql -U postgres -c "ALTER USER postgres PASSWORD 'postgres';" || true
    gosu postgres psql -U postgres -c "CREATE ROLE repmgr WITH LOGIN SUPERUSER REPLICATION PASSWORD 'repmgr';" || true
    gosu postgres psql -U postgres -c "CREATE DATABASE repmgr OWNER repmgr;" || true

    until pg_isready -h pg-primary -U repmgr -d repmgr > /dev/null 2>&1; do
        sleep 2
    done

    gosu postgres repmgr -f /etc/repmgr.conf witness register -h pg-primary -U repmgr -d repmgr || true
    gosu postgres repmgrd -f /etc/repmgr.conf --daemonize=false &
    
    wait -n
    exit 1
fi