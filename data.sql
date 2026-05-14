-- [ Таблица users ]
INSERT INTO users (username, email, password_hash, role) VALUES
    ('admin_sys', 'admin@salesanalytics.ru', '$2y$10$examplehashstringforadminpassword', 'admin'),
    ('ivanov_m', 'ivanov@salesanalytics.ru', '$2y$10$examplehashstringformanagerpassword', 'manager'),
    ('petrova_s', 'petrova@salesanalytics.ru', '$2y$10$examplehashstringforsupervisorpassword', 'supervisor');

-- [ Таблица categories ]
INSERT INTO categories (name, description) VALUES
    ('Электроника', 'Смартфоны, ноутбуки и аксессуары'),
    ('Одежда', 'Мужская и женская одежда, обувь'),
    ('Бытовая техника', 'Кухонная техника и климатическое оборудование');

-- [ Таблица customers ]
INSERT INTO customers (first_name, last_name, phone, email, loyalty_points) VALUES
    ('Алексей', 'Смирнов', '+79001234567', 'alex.smirnov@example.com', 150),
    ('Мария', 'Кузнецова', '+79007654321', 'maria.k@example.com', 320),
    ('Дмитрий', 'Волков', '+79009876543', 'd.volkov@example.com', 0);

-- [ Таблица products ]
INSERT INTO products (category_id, name, sku, price, cost_price, stock_quantity, is_active) VALUES
    (1, 'Смартфон Model X', 'ELEC-001', 45000.00, 32000.00, 50, true),
    (2, 'Футболка базовая', 'CLOTH-005', 1200.00, 400.00, 200, true),
    (3, 'Кофемашина Auto', 'HOME-012', 25000.00, 18000.00, 15, true);

-- [ Таблица sales ]
INSERT INTO sales (customer_id, user_id, sale_date, total_amount, status, comment) VALUES
    (1, 2, '2026-05-10 14:30:00', 45000.00, 'completed', 'Покупка смартфона'),
    (2, 2, '2026-05-12 10:15:00', 2400.00, 'completed', 'Покупка двух футболок'),
    (3, 2, '2026-05-14 16:45:00', 25000.00, 'completed', 'Покупка кофемашины');

-- [ Таблица sale_items ]
INSERT INTO sale_items (sale_id, product_id, quantity, price_at_sale, subtotal) VALUES
    (1, 1, 1, 45000.00, 45000.00),
    (2, 2, 2, 1200.00, 2400.00),
    (3, 3, 1, 25000.00, 25000.00);