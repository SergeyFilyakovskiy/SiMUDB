-- ========================================
-- Создание структуры БД интернет-магазина
-- ========================================

-- 1. Клиенты
CREATE TABLE IF NOT EXISTS clients (
    id         SERIAL PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    email      VARCHAR(255) UNIQUE NOT NULL,
    phone      VARCHAR(20),
    created_at TIMESTAMP DEFAULT now()
);

-- 2. Товары
CREATE TABLE IF NOT EXISTS products (
    id       SERIAL PRIMARY KEY,
    name     VARCHAR(200) NOT NULL,
    price    NUMERIC(10,2) NOT NULL,
    category VARCHAR(100)
);

-- 3. Заказы
CREATE TABLE IF NOT EXISTS orders (
    id           SERIAL PRIMARY KEY,
    client_id    INT REFERENCES clients(id),
    order_date   TIMESTAMP DEFAULT now(),
    status       VARCHAR(20) DEFAULT 'new',
    total_amount NUMERIC(12,2)
);

-- 4. Позиции заказа
CREATE TABLE IF NOT EXISTS order_items (
    id         SERIAL PRIMARY KEY,
    order_id   INT REFERENCES orders(id),
    product_id INT REFERENCES products(id),
    quantity   INT NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL,
    discount   NUMERIC(5,2) DEFAULT 0
);

-- Индексы для ускорения JOIN'ов (базовые)
CREATE INDEX IF NOT EXISTS idx_orders_client_id ON orders(client_id);
CREATE INDEX IF NOT EXISTS idx_orders_order_date ON orders(order_date);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);

-- Проверка создания
SELECT 'Tables created successfully' AS status;