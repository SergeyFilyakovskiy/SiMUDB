-- seed.sql
-- Генерация синтетических данных пользовательской активности
-- Данные: ~3 месяца, ~100K пользователей, разные паттерны активности

-- Настройки для генерации
SET max_threads = 4;
SET max_block_size = 65536;

-- Параметры генерации
-- Период: 90 дней
-- Пользователей: 100,000 (активных в разные дни)
-- Событий в день: от 100K до 1M (имитация пиков и спадов)

-- Вспомогательная таблица для генерации с распределением
-- Имитируем реальные паттерны: пики утром и вечером, спад ночью

-- ============================================================
-- Шаг 1: Генерация данных для всех 4 таблиц
-- ============================================================

-- Генерируем ~50 млн событий за 90 дней
-- Это примерно 500K-600K событий в день с пиками

INSERT INTO events_daily_userid
SELECT
    -- Временная метка: распределение по часам суток
    toDateTime('2026-06-20 00:00:00')
        + toIntervalDay(number % 90)
        + toIntervalHour(
            CASE
                -- Пики активности: 8-10 утра и 19-22 вечера
                WHEN rand() % 100 < 15 THEN 9   -- Утренний пик
                WHEN rand() % 100 < 25 THEN 10
                WHEN rand() % 100 < 35 THEN 19  -- Вечерний пик
                WHEN rand() % 100 < 45 THEN 20
                WHEN rand() % 100 < 55 THEN 21
                WHEN rand() % 100 < 65 THEN 14  -- Обед
                WHEN rand() % 100 < 75 THEN 16
                ELSE rand() % 24                 -- Равномерное распределение
            END
          )
        + toIntervalMinute(rand() % 60)
        + toIntervalSecond(rand() % 60) AS ts,

    -- User ID: 100K активных пользователей с разным уровнем активности
    -- Некоторые пользователи активнее других (распределение Парето)
    cityHash64(number % 100000, rand()) % 100000 + 1 AS user_id,

    -- Тип события с весами (чаще page_view, реже purchase)
    CASE
        WHEN rand() % 100 < 40 THEN 1  -- page_view
        WHEN rand() % 100 < 60 THEN 2  -- click
        WHEN rand() % 100 < 70 THEN 5  -- search
        WHEN rand() % 100 < 80 THEN 3  -- login
        WHEN rand() % 100 < 90 THEN 6  -- add_to_cart
        WHEN rand() % 100 < 95 THEN 7  -- logout
        ELSE 4                           -- purchase
    END AS event_type,

    -- Значение события (для purchase - сумма покупки)
    CASE
        WHEN (cityHash64(number % 100000, rand()) % 100 + 1) = 4
        THEN 10.0 + rand() % 990        -- Покупки: 10-1000
        ELSE rand() % 10                -- Остальные: 0-10
    END AS event_value,

    -- Session ID: сессии для каждого пользователя
    generateUUIDv4(cityHash64(
        number % 100000,
        toStartOfHour(toDateTime('2026-06-20 00:00:00') + toIntervalDay(number % 90))
    )) AS session_id,

    -- Тип устройства
    CASE
        WHEN rand() % 100 < 55 THEN 'mobile'
        WHEN rand() % 100 < 85 THEN 'desktop'
        ELSE 'tablet'
    END AS device_type,

    -- Страна
    CASE
        WHEN rand() % 100 < 35 THEN 'Russia'
        WHEN rand() % 100 < 55 THEN 'USA'
        WHEN rand() % 100 < 70 THEN 'Germany'
        WHEN rand() % 100 < 80 THEN 'UK'
        WHEN rand() % 100 < 90 THEN 'France'
        ELSE 'Other'
    END AS country,

    -- Длительность (секунды): для page_view и search - дольше
    CASE
        WHEN (cityHash64(number % 100000, rand()) % 100 + 1) IN (1, 5)
        THEN 5 + rand() % 295           -- 5-300 секунд
        ELSE 1 + rand() % 30            -- 1-30 секунд
    END AS duration
FROM numbers(50000000);

-- Копируем те же данные в остальные 3 таблицы
INSERT INTO events_daily_ts
SELECT * FROM events_daily_userid;

INSERT INTO events_monthly_userid
SELECT * FROM events_daily_userid;

INSERT INTO events_monthly_ts
SELECT * FROM events_daily_userid;

-- ============================================================
-- Шаг 2: Сравнение размеров таблиц
-- ============================================================

TRUNCATE TABLE table_sizes_compare;

INSERT INTO table_sizes_compare
SELECT
    table AS table_name,
    sum(rows) AS total_rows,
    sum(bytes_on_disk) AS total_bytes,
    sum(bytes_on_disk) / sum(rows) AS avg_bytes_per_row,
    count(DISTINCT partition) AS partition_count
FROM system.parts
WHERE database = currentDatabase()
  AND table IN ('events_daily_userid', 'events_daily_ts',
                'events_monthly_userid', 'events_monthly_ts')
  AND active = 1
GROUP BY table;

SELECT 'seed.sql: Данные успешно сгенерированы!' AS status;
SELECT * FROM table_sizes_compare;