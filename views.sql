CREATE OR REPLACE VIEW v_sales_details AS
SELECT
    s.id AS sale_id,
    s.sale_date,
    c.first_name || ' ' || c.last_name AS customer_name,
    u.username AS manager_name,
    p.name AS product_name,
    si.quantity,
    si.price_at_sale,
    si.subtotal,
    s.status
FROM sales s
JOIN users u ON s.user_id = u.id
LEFT JOIN customers c ON s.customer_id = c.id
JOIN sale_items si ON s.id = si.sale_id
JOIN products p ON si.product_id = p.id;

SELECT * FROM v_sales_details ORDER BY sale_date DESC;



CREATE OR REPLACE VIEW v_category_stats AS
SELECT
    cat.name AS category_name,
    COUNT(si.id) AS items_sold_count,
    SUM(si.subtotal) AS total_revenue
FROM sale_items si
JOIN products p ON si.product_id = p.id
JOIN categories cat ON p.category_id = cat.id
JOIN sales s ON si.sale_id = s.id
WHERE s.status = 'completed'
GROUP BY cat.name;

SELECT * FROM v_category_stats;