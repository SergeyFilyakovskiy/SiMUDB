-- init.sql
-- Создание таблиц для анализа пользовательской активности

-- Вспомогательный словарь для типов событий (для удобства)
CREATE DICTIONARY IF NOT EXISTS event_types_dict (
    event_id UInt8,
    event_name String,
    event_weight Float32
)
PRIMARY KEY event_id
SOURCE(CLICKHOUSE(TABLE 'event_types_src' DB 'default'))
LIFETIME(MIN 60 MAX 120)
LAYOUT(FLAT());

-- Таблица-источник для словаря (необходимо создать перед словарем)
CREATE TABLE IF NOT EXISTS event_types_src (
    event_id UInt8,
    event_name String,
    event_weight Float32
) ENGINE = TinyLog;

INSERT INTO event_types_src VALUES
    (1, 'page_view', 1.0),
    (2, 'click', 0.8),
    (3, 'login', 2.0),
    (4, 'purchase', 5.0),
    (5, 'search', 1.5),
    (6, 'add_to_cart', 3.0),
    (7, 'logout', 0.5);

-- ============================================================
-- Таблица 1: Партиция по ДНЮ, ключ сортировки (user_id, ts)
-- ============================================================
CREATE TABLE IF NOT EXISTS events_daily_userid (
    event_date Date MATERIALIZED toDate(ts),
    ts DateTime,
    user_id UInt64,
    event_type UInt8,
    event_value Float32,
    session_id UUID,
    device_type LowCardinality(String),
    country LowCardinality(String),
    duration UInt32 COMMENT 'Время на странице в секундах'
) ENGINE = MergeTree()
PARTITION BY toYYYYMMDD(ts)
ORDER BY (user_id, ts)
TTL ts + INTERVAL 1 YEAR
SETTINGS index_granularity = 8192;

-- ============================================================
-- Таблица 2: Партиция по ДНЮ, ключ сортировки (ts, user_id)
-- ============================================================
CREATE TABLE IF NOT EXISTS events_daily_ts (
    event_date Date MATERIALIZED toDate(ts),
    ts DateTime,
    user_id UInt64,
    event_type UInt8,
    event_value Float32,
    session_id UUID,
    device_type LowCardinality(String),
    country LowCardinality(String),
    duration UInt32 COMMENT 'Время на странице в секундах'
) ENGINE = MergeTree()
PARTITION BY toYYYYMMDD(ts)
ORDER BY (ts, user_id)
TTL ts + INTERVAL 1 YEAR
SETTINGS index_granularity = 8192;

-- ============================================================
-- Таблица 3: Партиция по МЕСЯЦУ, ключ сортировки (user_id, ts)
-- ============================================================
CREATE TABLE IF NOT EXISTS events_monthly_userid (
    event_date Date MATERIALIZED toDate(ts),
    ts DateTime,
    user_id UInt64,
    event_type UInt8,
    event_value Float32,
    session_id UUID,
    device_type LowCardinality(String),
    country LowCardinality(String),
    duration UInt32 COMMENT 'Время на странице в секундах'
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(ts)
ORDER BY (user_id, ts)
TTL ts + INTERVAL 1 YEAR
SETTINGS index_granularity = 8192;

-- ============================================================
-- Таблица 4: Партиция по МЕСЯЦУ, ключ сортировки (ts, user_id)
-- ============================================================
CREATE TABLE IF NOT EXISTS events_monthly_ts (
    event_date Date MATERIALIZED toDate(ts),
    ts DateTime,
    user_id UInt64,
    event_type UInt8,
    event_value Float32,
    session_id UUID,
    device_type LowCardinality(String),
    country LowCardinality(String),
    duration UInt32 COMMENT 'Время на странице в секундах'
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(ts)
ORDER BY (ts, user_id)
TTL ts + INTERVAL 1 YEAR
SETTINGS index_granularity = 8192;

-- ============================================================
-- Таблица для сравнения сжатия и размера
-- ============================================================
CREATE TABLE IF NOT EXISTS table_sizes_compare (
    table_name String,
    total_rows UInt64,
    total_bytes UInt64,
    avg_bytes_per_row Float64,
    partition_count UInt64
) ENGINE = MergeTree()
ORDER BY table_name;

-- ============================================================
-- Материализованное представление для агрегации по дням
-- (оптимизировано для аналитики)
-- ============================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_daily_stats
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(day)
ORDER BY (day, country, device_type)
AS SELECT
    toDate(ts) AS day,
    country,
    device_type,
    count() AS event_count,
    uniq(user_id) AS unique_users,
    sum(duration) AS total_duration,
    sum(event_value) AS total_value
FROM events_daily_userid
GROUP BY day, country, device_type;

-- Таблица для логирования времени выполнения запросов
CREATE TABLE IF NOT EXISTS query_performance_log (
    query_id String,
    query_name String,
    table_name String,
    execution_time_ms Float64,
    rows_read UInt64,
    bytes_read UInt64,
    query_text String,
    executed_at DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY (executed_at, query_id);

SELECT 'init.sql: Все таблицы успешно созданы!' AS status;