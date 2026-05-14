-- ============================================================
-- Создание ролей СУБД (PostgreSQL)
-- ============================================================

-- 1. Создание ролей (групп пользователей)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'role_analyst') THEN
        CREATE ROLE role_analyst;
    END IF;
    
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'role_manager') THEN
        CREATE ROLE role_manager;
    END IF;
    
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'role_admin') THEN
        CREATE ROLE role_admin;
    END IF;
END
$$;

-- 2. Предоставление прав на схему public (по умолчанию)
GRANT USAGE ON SCHEMA public TO role_analyst, role_manager, role_admin;

-- Привилегии роли 1: Аналитик (только чтение)
GRANT SELECT ON ALL TABLES IN SCHEMA public TO role_analyst;
-- Предоставляем право чтения на будущие таблицы
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO role_analyst;

-- Привилегии роли 2: Менеджер (работа с продажами)
-- Чтение справочников
GRANT SELECT ON categories, products, customers TO role_manager;
-- Работа с продажами
GRANT SELECT, INSERT, UPDATE ON sales, sale_items TO role_manager;
-- Использование последовательностей (для SERIAL полей)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO role_manager;
-- Выполнение хранимых процедур
GRANT EXECUTE ON PROCEDURE sp_add_sale(INTEGER, INTEGER, INTEGER, INTEGER) TO role_manager;
GRANT EXECUTE ON FUNCTION fn_get_manager_stats(INTEGER, DATE, DATE) TO role_manager;

-- Привилегии роли 3: Администратор (полный доступ)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO role_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO role_admin;
GRANT ALL PRIVILEGES ON SCHEMA public TO role_admin;

-- 3. Создание пользователей БД и назначение ролей
-- Пароли должны быть сложными. В реальном проекте используйте переменные окружения.

-- Пользователь-аналитик
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'user_analyst') THEN
        CREATE USER user_analyst WITH PASSWORD 'AnalystSecurePass123';
    END IF;
END
$$;
GRANT role_analyst TO user_analyst;

-- Пользователь-менеджер
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'user_manager') THEN
        CREATE USER user_manager WITH PASSWORD 'ManagerSecurePass123';
    END IF;
END
$$;
GRANT role_manager TO user_manager;

-- Пользователь-администратор
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'user_admin') THEN
        CREATE USER user_admin WITH PASSWORD 'AdminSuperSecurePass123';
    END IF;
END
$$;
GRANT role_admin TO user_admin;