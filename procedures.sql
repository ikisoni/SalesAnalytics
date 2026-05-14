CREATE OR REPLACE PROCEDURE sp_add_sale(
    IN p_customer_id INTEGER,
    IN p_user_id INTEGER,
    IN p_product_id INTEGER,
    IN p_quantity INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sale_id INTEGER;
    v_price DECIMAL(10,2);
    v_subtotal DECIMAL(12,2);
BEGIN
    -- Получаем текущую цену товара
    SELECT price INTO v_price FROM products WHERE id = p_product_id;
    
    IF v_price IS NULL THEN
        RAISE EXCEPTION 'Товар не найден';
    END IF;

    v_subtotal := v_price * p_quantity;

    -- Создаем запись о продаже
    INSERT INTO sales (customer_id, user_id, total_amount, status)
    VALUES (p_customer_id, p_user_id, v_subtotal, 'completed')
    RETURNING id INTO v_sale_id;

    -- Добавляем позицию в чек
    INSERT INTO sale_items (sale_id, product_id, quantity, price_at_sale, subtotal)
    VALUES (v_sale_id, p_product_id, p_quantity, v_price, v_subtotal);

END;
$$;

CALL sp_add_sale(1, 2, 2, 5);






CREATE OR REPLACE PROCEDURE sp_update_product_price(
    IN p_product_id INTEGER,
    IN p_new_price DECIMAL(10,2)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cost_price DECIMAL(10,2);
BEGIN
    SELECT cost_price INTO v_cost_price FROM products WHERE id = p_product_id;

    IF v_cost_price IS NOT NULL AND p_new_price < v_cost_price THEN
        RAISE WARNING 'Новая цена ниже себестоимости!';
    END IF;

    UPDATE products
    SET price = p_new_price
    WHERE id = p_product_id;
END;
$$;

-- Вызов:
CALL sp_update_product_price(1, 42000.00);






CREATE OR REPLACE PROCEDURE sp_get_manager_stats(
    IN p_user_id INTEGER,
    IN p_start_date DATE,
    IN p_end_date DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT 
        u.username,
        COUNT(s.id) AS total_sales,
        COALESCE(SUM(s.total_amount), 0) AS revenue
    FROM users u
    LEFT JOIN sales s ON u.id = s.user_id
        AND s.sale_date >= p_start_date
        AND s.sale_date <= p_end_date
    WHERE u.id = p_user_id
    GROUP BY u.username;
END;
$$;

CREATE OR REPLACE FUNCTION fn_get_manager_stats(
    p_user_id INTEGER,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (manager_name VARCHAR, total_sales BIGINT, revenue DECIMAL)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.username::VARCHAR,
        COUNT(s.id)::BIGINT,
        COALESCE(SUM(s.total_amount), 0)::DECIMAL
    FROM users u
    LEFT JOIN sales s ON u.id = s.user_id
        AND s.sale_date >= p_start_date
        AND s.sale_date <= p_end_date
    WHERE u.id = p_user_id
    GROUP BY u.username;
END;
$$;

-- Вызов функции:
SELECT * FROM fn_get_manager_stats(2, '2026-05-01', '2026-05-31');