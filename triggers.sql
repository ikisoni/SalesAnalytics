-- Таблица для логов
CREATE TABLE product_price_history (
    id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL,
    old_price DECIMAL(10,2),
    new_price DECIMAL(10,2),
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    changed_by VARCHAR(50) DEFAULT current_user
);
-- Функция триггера
CREATE OR REPLACE FUNCTION fn_log_price_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.price IS DISTINCT FROM NEW.price THEN
        INSERT INTO product_price_history (product_id, old_price, new_price)
        VALUES (OLD.id, OLD.price, NEW.price);
    END IF;
    RETURN NEW;
END;
$$;

-- Создание триггера
CREATE TRIGGER trg_log_price_change
AFTER UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION fn_log_price_change();

-- 1. Проверка текущего состояния таблицы логов (должна быть пуста)
SELECT * FROM product_price_history;

-- 2. Тестовое обновление цены товара с ID 1 (Смартфон Model X)
-- Меняем цену с 45000.00 на 46000.00
UPDATE products 
SET price = 46000.00 
WHERE id = 1;

-- 3. Проверка срабатывания триггера
-- В таблице должна появиться одна запись с old_price=45000.00 и new_price=46000.00
SELECT * FROM product_price_history ORDER BY changed_at DESC;






-- Функция триггера
CREATE OR REPLACE FUNCTION fn_calc_sale_total()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_total DECIMAL(12,2);
    v_sale_id INTEGER;
BEGIN
    -- Определяем ID продажи
    IF TG_OP = 'DELETE' THEN
        v_sale_id := OLD.sale_id;
    ELSE
        v_sale_id := NEW.sale_id;
    END IF;

    -- Считаем новую сумму
    SELECT COALESCE(SUM(subtotal), 0) INTO v_total
    FROM sale_items
    WHERE sale_id = v_sale_id;

    -- Обновляем таблицу продаж
    UPDATE sales
    SET total_amount = v_total
    WHERE id = v_sale_id;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

-- Создание триггеров на sale_items
CREATE TRIGGER trg_calc_sale_total_ins_upd
AFTER INSERT OR UPDATE ON sale_items
FOR EACH ROW
EXECUTE FUNCTION fn_calc_sale_total();

CREATE TRIGGER trg_calc_sale_total_del
AFTER DELETE ON sale_items
FOR EACH ROW
EXECUTE FUNCTION fn_calc_sale_total();
