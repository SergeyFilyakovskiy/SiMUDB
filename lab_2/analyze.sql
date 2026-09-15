-- =====================================================================
-- ЭТАП 0: Подготовительные настройки для детального EXPLAIN ANALYZE
-- =====================================================================
-- Включаем вывод статистики буферов (показывает, сколько данных читалось с диска/из RAM)
SET track_io_timing = on;

-- =====================================================================
-- ЭТАП 1: БАЗОВЫЙ АНАЛИТИЧЕСКИЙ ЗАПРОС (До оптимизации)
-- Задача: "Топ-100 клиентов по выручке в категории 'Electronics' за последние 6 месяцев"
-- =====================================================================
\echo '=========================================================='
\echo 'ЭТАП 1: БАЗОВЫЙ ЗАПРОС (4 таблицы, 3 JOIN, без доп. индексов)'
\echo '=========================================================='

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT 
    c.id AS client_id,
    c.name,
    c.email,
    COUNT(DISTINCT o.id) AS order_count,
    SUM(oi.quantity * oi.unit_price * (1 - oi.discount / 100.0)) AS total_revenue
FROM clients c
JOIN orders o ON o.client_id = c.id
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON p.id = oi.product_id
WHERE p.category = 'Electronics'
  AND o.order_date >= CURRENT_DATE - INTERVAL '6 months'
GROUP BY c.id, c.name, c.email
ORDER BY total_revenue DESC
LIMIT 100;


-- =====================================================================
-- ЭТАП 2: ОПТИМИЗАЦИЯ 1 — ДОБАВЛЕНИЕ ЦЕЛЕВЫХ ИНДЕКСОВ
-- =====================================================================
\echo '=========================================================='
\echo 'ЭТАП 2: СОЗДАНИЕ ОПТИМИЗИРОВАННЫХ ИНДЕКСОВ'
\echo '=========================================================='

-- Составной индекс для фильтрации по дате и быстрого JOIN по клиенту
CREATE INDEX IF NOT EXISTS idx_orders_date_client ON orders(order_date, client_id);

-- Составной индекс для позиций заказа (сначала order_id для JOIN, потом product_id для фильтрации)
CREATE INDEX IF NOT EXISTS idx_order_items_order_product ON order_items(order_id, product_id);

-- Индекс для категории товара
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);

\echo 'Индексы созданы. Повторяем запрос...'

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT 
    c.id AS client_id, c.name, c.email,
    COUNT(DISTINCT o.id) AS order_count,
    SUM(oi.quantity * oi.unit_price * (1 - oi.discount / 100.0)) AS total_revenue
FROM clients c
JOIN orders o ON o.client_id = c.id
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON p.id = oi.product_id
WHERE p.category = 'Electronics'
  AND o.order_date >= CURRENT_DATE - INTERVAL '6 months'
GROUP BY c.id, c.name, c.email
ORDER BY total_revenue DESC
LIMIT 100;


-- =====================================================================
-- ЭТАП 3: ОПТИМИЗАЦИЯ 2 — ПЕРЕПИСЫВАНИЕ SQL И СОКРАЩЕНИЕ JOIN (Денормализация)
-- =====================================================================
\echo '=========================================================='
\echo 'ЭТАП 3: ДЕНОРМАЛИЗАЦИЯ (Убираем JOIN с таблицей products)'
\echo '=========================================================='

-- 1. Добавляем категорию прямо в таблицу позиций заказа
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS category VARCHAR(100);

-- 2. Заполняем это поле историческими данными (один раз)
UPDATE order_items oi
SET category = p.category
FROM products p
WHERE oi.product_id = p.id AND oi.category IS NULL;

-- 3. Создаем индекс по новой колонке
CREATE INDEX IF NOT EXISTS idx_order_items_category ON order_items(category);

\echo 'Денормализация завершена. Повторяем запрос БЕЗ JOIN products...'

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT 
    c.id AS client_id, c.name, c.email,
    COUNT(DISTINCT o.id) AS order_count,
    SUM(oi.quantity * oi.unit_price * (1 - oi.discount / 100.0)) AS total_revenue
FROM clients c
JOIN orders o ON o.client_id = c.id
JOIN order_items oi ON oi.order_id = o.id
-- JOIN products p удален!
WHERE oi.category = 'Electronics'
  AND o.order_date >= CURRENT_DATE - INTERVAL '6 months'
GROUP BY c.id, c.name, c.email
ORDER BY total_revenue DESC
LIMIT 100;


-- =====================================================================
-- ЭТАП 4: ОПТИМИЗАЦИЯ 3 — ПАРТИЦИОНИРОВАНИЕ (Концепт и DDL)
-- =====================================================================
\echo '=========================================================='
\echo 'ЭТАП 4: ПАРТИЦИОНИРОВАНИЕ (DDL для справки)'
\echo '=========================================================='
-- Примечание: Полное пересоздание таблиц с данными в скрипте рискованно.
-- Здесь показана правильная структура для партиционирования по месяцам.
-- В реальном проекте данные мигрируют в такие таблицы при вставке.

CREATE TABLE IF NOT EXISTS orders_partitioned (
    id           INT,
    client_id    INT,
    order_date   TIMESTAMP NOT NULL,
    status       VARCHAR(20),
    total_amount NUMERIC(12,2)
) PARTITION BY RANGE (order_date);

-- Пример создания партиции за один месяц
CREATE TABLE IF NOT EXISTS orders_2023_10 PARTITION OF orders_partitioned
    FOR VALUES FROM ('2023-10-01') TO ('2023-11-01');

\echo 'См. вывод выше. Партиционирование позволяет БД полностью игнорировать'
\echo 'партиции, не попадающие в диапазон WHERE (Partition Pruning).'
\echo '=========================================================='


-- =====================================================================
-- ЭТАП 5: СВОДНАЯ СТАТИСТИКА ДЛЯ ОБОСНОВАНИЯ
-- =====================================================================
\echo '=========================================================='
\echo 'ЭТАП 5: СВОДНАЯ ИНФОРМАЦИЯ ПО РАЗМЕРАМ И ИНДЕКСАМ'
\echo '=========================================================='

SELECT 
    relname AS table_name,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
    pg_size_pretty(pg_relation_size(relid)) AS data_size,
    pg_size_pretty(pg_total_relation_size(relid) - pg_relation_size(relid)) AS index_size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;