-- ============================================================
-- База данных: sales_analytics_db
-- СУБД: PostgreSQL 15+
-- ============================================================
-- Удаление таблиц в обратном порядке для соблюдения зависимостей внешних ключей
DROP TABLE IF EXISTS sale_items CASCADE;
DROP TABLE IF EXISTS sales CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS users CASCADE;
-- Создание таблицы пользователей (сотрудников)
CREATE TABLE users (
id SERIAL PRIMARY KEY,
username VARCHAR(50) UNIQUE NOT NULL,
email VARCHAR(100) UNIQUE NOT NULL,
password_hash VARCHAR(255) NOT NULL,
role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'manager', 'supervisor')),
created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
-- Создание таблицы категорий товаров
CREATE TABLE categories (
id SERIAL PRIMARY KEY,
name VARCHAR(100) NOT NULL,
description TEXT
);
-- Создание таблицы клиентов
CREATE TABLE customers (
id SERIAL PRIMARY KEY,
first_name VARCHAR(50) NOT NULL,
last_name VARCHAR(50),
phone VARCHAR(20) UNIQUE,
email VARCHAR(100),
registration_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
loyalty_points INTEGER DEFAULT 0
);
-- Создание таблицы товаров
CREATE TABLE products (
id SERIAL PRIMARY KEY,
category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
name VARCHAR(150) NOT NULL,
sku VARCHAR(50) UNIQUE NOT NULL,
price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
cost_price DECIMAL(10, 2) CHECK (cost_price >= 0),
stock_quantity INTEGER DEFAULT 0 CHECK (stock_quantity >= 0),
is_active BOOLEAN DEFAULT TRUE
);
-- Создание таблицы продаж (чеков)
CREATE TABLE sales (
id SERIAL PRIMARY KEY,
customer_id INTEGER REFERENCES customers(id) ON DELETE SET NULL,
user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
sale_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
total_amount DECIMAL(12, 2) DEFAULT 0.00,
status VARCHAR(20) DEFAULT 'completed' CHECK (status IN ('completed', 'cancelled', 'refunded')),
comment TEXT
);
-- Создание таблицы позиций чека
CREATE TABLE sale_items (
id SERIAL PRIMARY KEY,
sale_id INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
quantity INTEGER NOT NULL CHECK (quantity > 0),
price_at_sale DECIMAL(10, 2) NOT NULL CHECK (price_at_sale >= 0),
subtotal DECIMAL(12, 2) NOT NULL CHECK (subtotal >= 0)
);
-- Индексы для ускорения выборок и аналитики
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_sales_user ON sales(user_id);
CREATE INDEX idx_sales_customer ON sales(customer_id);
CREATE INDEX idx_sales_date ON sales(sale_date);
CREATE INDEX idx_sale_items_sale ON sale_items(sale_id);
CREATE INDEX idx_sale_items_product ON sale_items(product_id);