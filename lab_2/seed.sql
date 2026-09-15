-- ========================================
-- Генератор тестовых данных для e-commerce
-- ========================================

-- Очищаем таблицы (если нужно перезапустить)
TRUNCATE order_items, orders, products, clients RESTART IDENTITY CASCADE;

-- 1. Клиенты (10 000 записей)
INSERT INTO clients (name, email, phone)
SELECT 
    'Client ' || i,
    'client' || i || '@example.com',
    '+7' || lpad((9000000000 + i)::text, 10, '0')
FROM generate_series(1, 10000) AS i;

-- 2. Товары (1 000 записей)
INSERT INTO products (name, price, category)
SELECT 
    'Product ' || i,
    (random() * 9000 + 100)::numeric(10,2),  -- цена от 100 до 9100
    CASE (i % 5)
        WHEN 0 THEN 'Electronics'
        WHEN 1 THEN 'Books'
        WHEN 2 THEN 'Clothing'
        WHEN 3 THEN 'Home'
        ELSE 'Sports'
    END
FROM generate_series(1, 1000) AS i;

-- 3. Заказы (500 000 записей за последние 2 года)
INSERT INTO orders (client_id, order_date, status, total_amount)
SELECT 
    (random() * 9999 + 1)::int,  -- случайный client_id от 1 до 10000
    CURRENT_DATE - (random() * 730)::int,  -- дата за последние 2 года
    CASE (i % 4)
        WHEN 0 THEN 'new'
        WHEN 1 THEN 'paid'
        WHEN 2 THEN 'shipped'
        ELSE 'done'
    END,
    0  -- временно, пересчитаем ниже
FROM generate_series(1, 500000) AS i;

-- 4. Позиции заказа (в среднем 3 позиции на заказ = ~1.5M записей)
INSERT INTO order_items (order_id, product_id, quantity, unit_price, discount)
SELECT 
    o.id,
    (random() * 999 + 1)::int,  -- случайный product_id от 1 до 1000
    (random() * 5 + 1)::int,    -- количество от 1 до 5
    p.price,
    CASE WHEN random() < 0.2 THEN (random() * 20)::numeric(5,2) ELSE 0 END  -- 20% заказов со скидкой
FROM orders o
CROSS JOIN generate_series(1, 3) AS g  -- 3 позиции на заказ
JOIN products p ON p.id = (random() * 999 + 1)::int;

-- 5. Пересчитываем total_amount в orders
UPDATE orders o
SET total_amount = (
    SELECT COALESCE(SUM(oi.quantity * oi.unit_price * (1 - oi.discount/100)), 0)
    FROM order_items oi
    WHERE oi.order_id = o.id
);

-- Проверяем результат
SELECT 
    'clients' AS table_name, count(*) FROM clients
UNION ALL
SELECT 'products', count(*) FROM products
UNION ALL
SELECT 'orders', count(*) FROM orders
UNION ALL
SELECT 'order_items', count(*) FROM order_items;