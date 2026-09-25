-- analyze.sql
-- Аналитический скрипт: сравнение партиций, ключей, анализ активности

SET max_threads = 4;

-- ============================================================
-- БЛОК 1: Сравнение размеров и структуры партиций
-- ============================================================

-- 1.1 Сравнение размеров таблиц
SELECT
    '=== Сравнение размеров таблиц ===' AS section;

SELECT
    table_name,
    formatReadableSize(total_bytes) AS total_size,
    total_rows AS rows_count,
    avg_bytes_per_row AS bytes_per_row,
    partition_count AS partitions
FROM table_sizes_compare
ORDER BY total_bytes;

-- 1.2 Информация о партициях
SELECT
    '=== Партиции по таблице ===' AS section;

SELECT
    table,
    partition,
    partition_id,
    rows,
    formatReadableSize(bytes_on_disk) AS size
FROM system.parts
WHERE database = currentDatabase()
  AND table IN ('events_daily_userid', 'events_daily_ts',
                'events_monthly_userid', 'events_monthly_ts')
  AND active = 1
ORDER BY table, partition;

-- ============================================================
-- БЛОК 2: Сравнение производительности запросов
-- ============================================================

-- Функция для логирования времени (через system.query_log)
-- Запускаем запросы и собираем статистику

-- 2.1 Запрос: Активность одного пользователя (поиск по user_id)
-- Ключ (user_id, ts) должен быть быстрее
SELECT
    '=== Q1: Поиск событий конкретного пользователя ===' AS query_name;

-- events_daily_userid (ключ: user_id, ts) - ожидаем быстро
SELECT
    'events_daily_userid' AS table_name,
    count() AS events,
    min(ts) AS first_event,
    max(ts) AS last_event,
    sum(event_value) AS total_value,
    uniq(session_id) AS sessions
FROM events_daily_userid
WHERE user_id = 12345
  AND ts >= '2026-06-20'
  AND ts < '2026-09-18';

-- events_daily_ts (ключ: ts, user_id) - может быть медленнее
SELECT
    'events_daily_ts' AS table_name,
    count() AS events,
    min(ts) AS first_event,
    max(ts) AS last_event,
    sum(event_value) AS total_value,
    uniq(session_id) AS sessions
FROM events_daily_ts
WHERE user_id = 12345
  AND ts >= '2026-06-20'
  AND ts < '2026-09-18';

-- 2.2 Запрос: Активность за конкретный час (поиск по ts)
-- Ключ (ts, user_id) должен быть быстрее
SELECT
    '=== Q2: Поиск событий за конкретный час ===' AS query_name;

-- events_daily_userid (ключ: user_id, ts) - медленнее для временных окон
SELECT
    'events_daily_userid' AS table_name,
    count() AS events,
    uniq(user_id) AS unique_users
FROM events_daily_userid
WHERE ts >= '2026-07-15 14:00:00'
  AND ts < '2026-07-15 15:00:00';

-- events_daily_ts (ключ: ts, user_id) - быстрее для временных окон
SELECT
    'events_daily_ts' AS table_name,
    count() AS events,
    uniq(user_id) AS unique_users
FROM events_daily_ts
WHERE ts >= '2026-07-15 14:00:00'
  AND ts < '2026-07-15 15:00:00';

-- 2.3 Запрос: Диапазон дат (PARTITION BY влияние)
SELECT
    '=== Q3: Сравнение партиций - диапазон дат ===' AS query_name;

-- Daily partition - должно быть быстрее при узком диапазоне
SELECT
    'events_daily_userid (PARTITION BY DAY)' AS table_name,
    count() AS events,
    uniq(user_id) AS users
FROM events_daily_userid
WHERE ts >= '2026-07-10'
  AND ts < '2026-07-13';

SELECT
    'events_monthly_userid (PARTITION BY MONTH)' AS table_name,
    count() AS events,
    uniq(user_id) AS users
FROM events_monthly_userid
WHERE ts >= '2026-07-10'
  AND ts < '2026-07-13';

-- ============================================================
-- БЛОК 3: Анализ пользовательской активности
-- ============================================================

-- 3.1 DAU / WAU / MAU
SELECT
    '=== DAU, WAU, MAU ===' AS analysis;

SELECT
    'DAU (avg)' AS metric,
    toFloat64(round(avg(daily_users))) AS value
FROM (
    SELECT toDate(ts) AS day, uniq(user_id) AS daily_users
    FROM events_daily_userid
    GROUP BY day
)

UNION ALL

SELECT
    'WAU (avg)' AS metric,
    toFloat64(round(avg(weekly_users))) AS value
FROM (
    SELECT toStartOfWeek(ts) AS week, uniq(user_id) AS weekly_users
    FROM events_daily_userid
    GROUP BY week
)

UNION ALL

SELECT
    'MAU' AS metric,
    toFloat64(uniq(user_id)) AS value
FROM events_daily_userid;

-- 3.2 Распределение активности по времени суток
SELECT
    '=== Активность по часам ===' AS analysis;

SELECT
    toHour(ts) AS hour,
    count() AS events,
    uniq(user_id) AS unique_users,
    round(avg(duration)) AS avg_duration_sec
FROM events_daily_userid
GROUP BY hour
ORDER BY hour;

-- 3.3 Повторные визиты (Retention по когортам)
SELECT
    '=== Retention Analysis ===' AS analysis;

WITH
    -- Первая активность каждого пользователя
    cohort_start AS (
        SELECT
            user_id,
            toDate(min(ts)) AS first_day
        FROM events_daily_userid
        GROUP BY user_id
    ),
    -- Когорта (по неделе первого визита)
    user_cohorts AS (
        SELECT
            user_id,
            toStartOfWeek(first_day) AS cohort_week
        FROM cohort_start
    ),
    -- Активность по неделям
    weekly_activity AS (
        SELECT
            user_id,
            toStartOfWeek(ts) AS activity_week
        FROM events_daily_userid
        GROUP BY user_id, activity_week
    )
SELECT
    cohort_week,
    count(DISTINCT uc.user_id) AS cohort_size,
    countIf(wa.activity_week = cohort_week) AS week_0,
    countIf(wa.activity_week = cohort_week + INTERVAL 1 WEEK) AS week_1,
    countIf(wa.activity_week = cohort_week + INTERVAL 2 WEEK) AS week_2,
    countIf(wa.activity_week = cohort_week + INTERVAL 3 WEEK) AS week_3,
    round(100 * countIf(wa.activity_week = cohort_week + INTERVAL 1 WEEK) / cohort_size, 1) AS retention_w1_pct,
    round(100 * countIf(wa.activity_week = cohort_week + INTERVAL 2 WEEK) / cohort_size, 1) AS retention_w2_pct,
    round(100 * countIf(wa.activity_week = cohort_week + INTERVAL 3 WEEK) / cohort_size, 1) AS retention_w3_pct
FROM user_cohorts uc
LEFT JOIN weekly_activity wa ON uc.user_id = wa.user_id
GROUP BY cohort_week
ORDER BY cohort_week;

-- 3.4 Анализ "залипания" пользователей
SELECT
    '=== Топ пользователей по активности ===' AS analysis;

SELECT
    user_id,
    count() AS total_events,
    uniq(toDate(ts)) AS active_days,
    uniq(session_id) AS total_sessions,
    sum(duration) / 60 AS total_minutes,
    round(count() / uniq(toDate(ts)), 1) AS events_per_day,
    dateDiff('day', min(toDate(ts)), max(toDate(ts))) AS lifetime_days
FROM events_daily_userid
GROUP BY user_id
ORDER BY total_events DESC
LIMIT 20;

-- 3.5 Воронка событий
SELECT
    '=== Event Funnel ===' AS analysis;

SELECT
    event_type,
    count() AS events,
    uniq(user_id) AS unique_users,
    round(100 * count() / (SELECT count() FROM events_daily_userid), 2) AS pct_of_total
FROM events_daily_userid
GROUP BY event_type
ORDER BY events DESC;

-- 3.6 Географическое распределение
SELECT
    '=== Активность по странам ===' AS analysis;

SELECT
    country,
    count() AS events,
    uniq(user_id) AS users,
    round(count() / uniq(user_id), 1) AS events_per_user,
    round(avg(duration), 1) AS avg_duration
FROM events_daily_userid
GROUP BY country
ORDER BY events DESC;

-- 3.7 Устройство и поведение
SELECT
    '=== Распределение по устройствам ===' AS analysis;

SELECT
    device_type,
    count() AS events,
    uniq(user_id) AS users,
    round(sumIf(event_value, event_type = 4), 2) AS total_purchase_value,
    countIf(event_type = 4) AS purchases,
    round(countIf(event_type = 4) / uniq(user_id) * 100, 2) AS conversion_rate_pct
FROM events_daily_userid
GROUP BY device_type
ORDER BY events DESC;

-- ============================================================
-- БЛОК 4: Анализ нагрузки и выводы
-- ============================================================

-- 4.1 Пиковая нагрузка (по часам)
SELECT
    '=== Пиковые часы нагрузки ===' AS analysis;

SELECT
    toDate(ts) AS day,
    toHour(ts) AS hour,
    count() AS requests,
    uniq(user_id) AS users,
    round(count() / 3600, 2) AS req_per_sec
FROM events_daily_userid
GROUP BY day, hour
HAVING requests > (
    SELECT quantile(0.95)(hourly_reqs)
    FROM (
        SELECT count() AS hourly_reqs
        FROM events_daily_userid
        GROUP BY toDate(ts), toHour(ts)
    )
)
ORDER BY requests DESC
LIMIT 20;

-- 4.2 Нагрузка по дням недели
SELECT
    '=== Нагрузка по дням недели ===' AS analysis;

SELECT
    toDayOfWeek(ts) AS day_num,
    dateName('weekday', ts) AS day_name,
    avg(events_per_day) AS avg_events,
    avg(users_per_day) AS avg_users
FROM (
    SELECT
        toDate(ts) AS day,
        toDayOfWeek(ts) AS day_num,
        ts,
        count() OVER (PARTITION BY toDate(ts)) AS events_per_day,
        uniq(user_id) OVER (PARTITION BY toDate(ts)) AS users_per_day
    FROM events_daily_userid
    GROUP BY day, day_num, ts, user_id
)
GROUP BY day_num, day_name
ORDER BY day_num;

-- 4.3 Сводная таблица сравнения
SELECT
    '=== ИТОГОВОЕ СРАВНЕНИЕ ===' AS final;

SELECT
    'PARTITION BY' AS criterion,
    'DAY' AS daily_config,
    'MONTH' AS monthly_config,
    'Дневная партиция лучше для: точечных запросов по датам, частого TTL, OLTP-нагрузки' AS recommendation

UNION ALL

SELECT
    'ORDER BY',
    '(user_id, ts)',
    '(ts, user_id)',
    '(user_id, ts) оптимален для: аналитики пользователей, profile lookups; (ts, user_id) - для time-series, дашбордов по времени'

UNION ALL

SELECT
    'Compression',
    'Больше партиций = чуть больше overhead, но лучше pruning',
    'Меньше партиций = меньше overhead, но хуже pruning для точечных запросов',
    'Выбор зависит от паттерна запросов'

UNION ALL

SELECT
    'Рекомендация для варианта 12',
    'events_daily_userid',
    '-',
    'Для аналитики пользователей партиция по ДНЮ + ключ (user_id, ts) дает лучший баланс производительности и гибкости';

-- 4.4 EXPLAIN для демонстрации эффективности
SELECT '=== EXPLAIN для ключа (user_id, ts) ===' AS explain_section;

EXPLAIN indexes = 1
SELECT count()
FROM events_daily_userid
WHERE user_id = 12345
  AND ts >= '2026-07-01'
  AND ts < '2026-08-01';

SELECT '=== EXPLAIN для ключа (ts, user_id) ===' AS explain_section;

EXPLAIN indexes = 1
SELECT count()
FROM events_daily_ts
WHERE user_id = 12345
  AND ts >= '2026-07-01'
  AND ts < '2026-08-01';

SELECT '=== analyze.sql: Анализ завершен ===' AS status;