--
-- PostgreSQL database dump
--

\restrict Gtidh4cSMUK3lhWCawrDgp7RzOdy5UjtKj2DCJ7eN0AKwLbjMKgL04Ar2r5J9Br

-- Dumped from database version 15.17 (Debian 15.17-1.pgdg13+1)
-- Dumped by pg_dump version 15.17 (Debian 15.17-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: fn_calc_sale_total(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_calc_sale_total() RETURNS trigger
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


ALTER FUNCTION public.fn_calc_sale_total() OWNER TO postgres;

--
-- Name: fn_get_manager_stats(integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_get_manager_stats(p_user_id integer, p_start_date date, p_end_date date) RETURNS TABLE(manager_name character varying, total_sales bigint, revenue numeric)
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


ALTER FUNCTION public.fn_get_manager_stats(p_user_id integer, p_start_date date, p_end_date date) OWNER TO postgres;

--
-- Name: fn_log_price_change(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_log_price_change() RETURNS trigger
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


ALTER FUNCTION public.fn_log_price_change() OWNER TO postgres;

--
-- Name: sp_add_sale(integer, integer, integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_add_sale(IN p_customer_id integer, IN p_user_id integer, IN p_product_id integer, IN p_quantity integer)
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


ALTER PROCEDURE public.sp_add_sale(IN p_customer_id integer, IN p_user_id integer, IN p_product_id integer, IN p_quantity integer) OWNER TO postgres;

--
-- Name: sp_get_manager_stats(integer, date, date); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_get_manager_stats(IN p_user_id integer, IN p_start_date date, IN p_end_date date)
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


ALTER PROCEDURE public.sp_get_manager_stats(IN p_user_id integer, IN p_start_date date, IN p_end_date date) OWNER TO postgres;

--
-- Name: sp_register_user(character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_register_user(IN p_username character varying, IN p_password_hash character varying, IN p_full_name character varying, IN p_email character varying, IN p_phone character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO users (username, password_hash, role, full_name, email, phone, created_at)
    VALUES (p_username, p_password_hash, 'client', p_full_name, p_email, p_phone, NOW());
END;
$$;


ALTER PROCEDURE public.sp_register_user(IN p_username character varying, IN p_password_hash character varying, IN p_full_name character varying, IN p_email character varying, IN p_phone character varying) OWNER TO postgres;

--
-- Name: sp_update_product_price(integer, numeric); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_update_product_price(IN p_product_id integer, IN p_new_price numeric)
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


ALTER PROCEDURE public.sp_update_product_price(IN p_product_id integer, IN p_new_price numeric) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.categories (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    description text
);


ALTER TABLE public.categories OWNER TO postgres;

--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.categories_id_seq OWNER TO postgres;

--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- Name: customers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.customers (
    id integer NOT NULL,
    first_name character varying(50) NOT NULL,
    last_name character varying(50),
    phone character varying(20),
    email character varying(100),
    registration_date timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    loyalty_points integer DEFAULT 0
);


ALTER TABLE public.customers OWNER TO postgres;

--
-- Name: customers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.customers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.customers_id_seq OWNER TO postgres;

--
-- Name: customers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.customers_id_seq OWNED BY public.customers.id;


--
-- Name: product_price_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.product_price_history (
    id integer NOT NULL,
    product_id integer NOT NULL,
    old_price numeric(10,2),
    new_price numeric(10,2),
    changed_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    changed_by character varying(50) DEFAULT CURRENT_USER
);


ALTER TABLE public.product_price_history OWNER TO postgres;

--
-- Name: product_price_history_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.product_price_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.product_price_history_id_seq OWNER TO postgres;

--
-- Name: product_price_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.product_price_history_id_seq OWNED BY public.product_price_history.id;


--
-- Name: products; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.products (
    id integer NOT NULL,
    category_id integer NOT NULL,
    name character varying(150) NOT NULL,
    sku character varying(50) NOT NULL,
    price numeric(10,2) NOT NULL,
    cost_price numeric(10,2),
    stock_quantity integer DEFAULT 0,
    is_active boolean DEFAULT true,
    CONSTRAINT products_cost_price_check CHECK ((cost_price >= (0)::numeric)),
    CONSTRAINT products_price_check CHECK ((price >= (0)::numeric)),
    CONSTRAINT products_stock_quantity_check CHECK ((stock_quantity >= 0))
);


ALTER TABLE public.products OWNER TO postgres;

--
-- Name: products_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.products_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.products_id_seq OWNER TO postgres;

--
-- Name: products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.products_id_seq OWNED BY public.products.id;


--
-- Name: sale_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sale_items (
    id integer NOT NULL,
    sale_id integer NOT NULL,
    product_id integer NOT NULL,
    quantity integer NOT NULL,
    price_at_sale numeric(10,2) NOT NULL,
    subtotal numeric(12,2) NOT NULL,
    CONSTRAINT sale_items_price_at_sale_check CHECK ((price_at_sale >= (0)::numeric)),
    CONSTRAINT sale_items_quantity_check CHECK ((quantity > 0)),
    CONSTRAINT sale_items_subtotal_check CHECK ((subtotal >= (0)::numeric))
);


ALTER TABLE public.sale_items OWNER TO postgres;

--
-- Name: sale_items_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sale_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sale_items_id_seq OWNER TO postgres;

--
-- Name: sale_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sale_items_id_seq OWNED BY public.sale_items.id;


--
-- Name: sales; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sales (
    id integer NOT NULL,
    customer_id integer,
    user_id integer NOT NULL,
    sale_date timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    total_amount numeric(12,2) DEFAULT 0.00,
    status character varying(20) DEFAULT 'completed'::character varying,
    comment text,
    CONSTRAINT sales_status_check CHECK (((status)::text = ANY ((ARRAY['completed'::character varying, 'cancelled'::character varying, 'refunded'::character varying])::text[])))
);


ALTER TABLE public.sales OWNER TO postgres;

--
-- Name: sales_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sales_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sales_id_seq OWNER TO postgres;

--
-- Name: sales_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sales_id_seq OWNED BY public.sales.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    username character varying(50) NOT NULL,
    email character varying(100) NOT NULL,
    password_hash character varying(255) NOT NULL,
    role character varying(20) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT users_role_check CHECK (((role)::text = ANY ((ARRAY['admin'::character varying, 'manager'::character varying, 'supervisor'::character varying])::text[])))
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: v_category_stats; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_category_stats AS
 SELECT cat.name AS category_name,
    count(si.id) AS items_sold_count,
    sum(si.subtotal) AS total_revenue
   FROM (((public.sale_items si
     JOIN public.products p ON ((si.product_id = p.id)))
     JOIN public.categories cat ON ((p.category_id = cat.id)))
     JOIN public.sales s ON ((si.sale_id = s.id)))
  WHERE ((s.status)::text = 'completed'::text)
  GROUP BY cat.name;


ALTER TABLE public.v_category_stats OWNER TO postgres;

--
-- Name: v_sales_details; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_sales_details AS
 SELECT s.id AS sale_id,
    s.sale_date,
    (((c.first_name)::text || ' '::text) || (c.last_name)::text) AS customer_name,
    u.username AS manager_name,
    p.name AS product_name,
    si.quantity,
    si.price_at_sale,
    si.subtotal,
    s.status
   FROM ((((public.sales s
     JOIN public.users u ON ((s.user_id = u.id)))
     LEFT JOIN public.customers c ON ((s.customer_id = c.id)))
     JOIN public.sale_items si ON ((s.id = si.sale_id)))
     JOIN public.products p ON ((si.product_id = p.id)));


ALTER TABLE public.v_sales_details OWNER TO postgres;

--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: customers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers ALTER COLUMN id SET DEFAULT nextval('public.customers_id_seq'::regclass);


--
-- Name: product_price_history id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product_price_history ALTER COLUMN id SET DEFAULT nextval('public.product_price_history_id_seq'::regclass);


--
-- Name: products id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products ALTER COLUMN id SET DEFAULT nextval('public.products_id_seq'::regclass);


--
-- Name: sale_items id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_items ALTER COLUMN id SET DEFAULT nextval('public.sale_items_id_seq'::regclass);


--
-- Name: sales id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales ALTER COLUMN id SET DEFAULT nextval('public.sales_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Data for Name: categories; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.categories (id, name, description) FROM stdin;
1	Электроника	Смартфоны, ноутбуки и аксессуары
2	Одежда	Мужская и женская одежда, обувь
3	Бытовая техника	Кухонная техника и климатическое оборудование
\.


--
-- Data for Name: customers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.customers (id, first_name, last_name, phone, email, registration_date, loyalty_points) FROM stdin;
1	Алексей	Смирнов	+79001234567	alex.smirnov@example.com	2026-05-14 17:27:37.98977+00	150
2	Мария	Кузнецова	+79007654321	maria.k@example.com	2026-05-14 17:27:37.98977+00	320
3	Дмитрий	Волков	+79009876543	d.volkov@example.com	2026-05-14 17:27:37.98977+00	0
\.


--
-- Data for Name: product_price_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.product_price_history (id, product_id, old_price, new_price, changed_at, changed_by) FROM stdin;
1	1	42000.00	46000.00	2026-05-14 18:03:18.559308+00	postgres
\.


--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.products (id, category_id, name, sku, price, cost_price, stock_quantity, is_active) FROM stdin;
2	2	Футболка базовая	CLOTH-005	1200.00	400.00	200	t
3	3	Кофемашина Auto	HOME-012	25000.00	18000.00	15	t
1	1	Смартфон Model X	ELEC-001	46000.00	32000.00	50	t
\.


--
-- Data for Name: sale_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sale_items (id, sale_id, product_id, quantity, price_at_sale, subtotal) FROM stdin;
1	1	1	1	45000.00	45000.00
2	2	2	2	1200.00	2400.00
3	3	3	1	25000.00	25000.00
4	4	2	5	1200.00	6000.00
5	5	3	1	25000.00	25000.00
6	6	3	1	25000.00	25000.00
\.


--
-- Data for Name: sales; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sales (id, customer_id, user_id, sale_date, total_amount, status, comment) FROM stdin;
1	1	2	2026-05-10 14:30:00+00	45000.00	completed	Покупка смартфона
2	2	2	2026-05-12 10:15:00+00	2400.00	completed	Покупка двух футболок
3	3	2	2026-05-14 16:45:00+00	25000.00	completed	Покупка кофемашины
4	1	2	2026-05-14 18:00:17.938216+00	6000.00	completed	\N
5	2	2	2026-05-14 18:33:15.382459+00	25000.00	completed	\N
6	2	2	2026-05-14 18:33:19.324305+00	25000.00	completed	\N
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, username, email, password_hash, role, created_at) FROM stdin;
1	admin_sys	admin@salesanalytics.ru	$2y$10$examplehashstringforadminpassword	admin	2026-05-14 17:27:37.98977+00
2	ivanov_m	ivanov@salesanalytics.ru	$2y$10$examplehashstringformanagerpassword	manager	2026-05-14 17:27:37.98977+00
3	petrova_s	petrova@salesanalytics.ru	$2y$10$examplehashstringforsupervisorpassword	supervisor	2026-05-14 17:27:37.98977+00
\.


--
-- Name: categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.categories_id_seq', 3, true);


--
-- Name: customers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.customers_id_seq', 3, true);


--
-- Name: product_price_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.product_price_history_id_seq', 1, true);


--
-- Name: products_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.products_id_seq', 3, true);


--
-- Name: sale_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.sale_items_id_seq', 6, true);


--
-- Name: sales_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.sales_id_seq', 6, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 3, true);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: customers customers_phone_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_phone_key UNIQUE (phone);


--
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (id);


--
-- Name: product_price_history product_price_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product_price_history
    ADD CONSTRAINT product_price_history_pkey PRIMARY KEY (id);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: products products_sku_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_sku_key UNIQUE (sku);


--
-- Name: sale_items sale_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_items
    ADD CONSTRAINT sale_items_pkey PRIMARY KEY (id);


--
-- Name: sales sales_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales
    ADD CONSTRAINT sales_pkey PRIMARY KEY (id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: idx_products_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_products_category ON public.products USING btree (category_id);


--
-- Name: idx_sale_items_product; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sale_items_product ON public.sale_items USING btree (product_id);


--
-- Name: idx_sale_items_sale; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sale_items_sale ON public.sale_items USING btree (sale_id);


--
-- Name: idx_sales_customer; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sales_customer ON public.sales USING btree (customer_id);


--
-- Name: idx_sales_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sales_date ON public.sales USING btree (sale_date);


--
-- Name: idx_sales_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sales_user ON public.sales USING btree (user_id);


--
-- Name: sale_items trg_calc_sale_total_del; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_calc_sale_total_del AFTER DELETE ON public.sale_items FOR EACH ROW EXECUTE FUNCTION public.fn_calc_sale_total();


--
-- Name: sale_items trg_calc_sale_total_ins_upd; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_calc_sale_total_ins_upd AFTER INSERT OR UPDATE ON public.sale_items FOR EACH ROW EXECUTE FUNCTION public.fn_calc_sale_total();


--
-- Name: products trg_log_price_change; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_log_price_change AFTER UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.fn_log_price_change();


--
-- Name: products products_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE RESTRICT;


--
-- Name: sale_items sale_items_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_items
    ADD CONSTRAINT sale_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT;


--
-- Name: sale_items sale_items_sale_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_items
    ADD CONSTRAINT sale_items_sale_id_fkey FOREIGN KEY (sale_id) REFERENCES public.sales(id) ON DELETE CASCADE;


--
-- Name: sales sales_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales
    ADD CONSTRAINT sales_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE SET NULL;


--
-- Name: sales sales_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales
    ADD CONSTRAINT sales_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO role_analyst;
GRANT USAGE ON SCHEMA public TO role_manager;
GRANT ALL ON SCHEMA public TO role_admin;


--
-- Name: FUNCTION fn_get_manager_stats(p_user_id integer, p_start_date date, p_end_date date); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fn_get_manager_stats(p_user_id integer, p_start_date date, p_end_date date) TO role_manager;


--
-- Name: PROCEDURE sp_add_sale(IN p_customer_id integer, IN p_user_id integer, IN p_product_id integer, IN p_quantity integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.sp_add_sale(IN p_customer_id integer, IN p_user_id integer, IN p_product_id integer, IN p_quantity integer) TO role_manager;


--
-- Name: TABLE categories; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.categories TO role_analyst;
GRANT SELECT ON TABLE public.categories TO role_manager;
GRANT ALL ON TABLE public.categories TO role_admin;


--
-- Name: SEQUENCE categories_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.categories_id_seq TO role_manager;
GRANT ALL ON SEQUENCE public.categories_id_seq TO role_admin;


--
-- Name: TABLE customers; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.customers TO role_analyst;
GRANT SELECT ON TABLE public.customers TO role_manager;
GRANT ALL ON TABLE public.customers TO role_admin;


--
-- Name: SEQUENCE customers_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.customers_id_seq TO role_manager;
GRANT ALL ON SEQUENCE public.customers_id_seq TO role_admin;


--
-- Name: TABLE product_price_history; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.product_price_history TO role_analyst;
GRANT ALL ON TABLE public.product_price_history TO role_admin;


--
-- Name: SEQUENCE product_price_history_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.product_price_history_id_seq TO role_manager;
GRANT ALL ON SEQUENCE public.product_price_history_id_seq TO role_admin;


--
-- Name: TABLE products; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.products TO role_analyst;
GRANT SELECT ON TABLE public.products TO role_manager;
GRANT ALL ON TABLE public.products TO role_admin;


--
-- Name: SEQUENCE products_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.products_id_seq TO role_manager;
GRANT ALL ON SEQUENCE public.products_id_seq TO role_admin;


--
-- Name: TABLE sale_items; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sale_items TO role_analyst;
GRANT SELECT,INSERT,UPDATE ON TABLE public.sale_items TO role_manager;
GRANT ALL ON TABLE public.sale_items TO role_admin;


--
-- Name: SEQUENCE sale_items_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.sale_items_id_seq TO role_manager;
GRANT ALL ON SEQUENCE public.sale_items_id_seq TO role_admin;


--
-- Name: TABLE sales; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sales TO role_analyst;
GRANT SELECT,INSERT,UPDATE ON TABLE public.sales TO role_manager;
GRANT ALL ON TABLE public.sales TO role_admin;


--
-- Name: SEQUENCE sales_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.sales_id_seq TO role_manager;
GRANT ALL ON SEQUENCE public.sales_id_seq TO role_admin;


--
-- Name: TABLE users; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.users TO role_analyst;
GRANT ALL ON TABLE public.users TO role_admin;


--
-- Name: SEQUENCE users_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.users_id_seq TO role_manager;
GRANT ALL ON SEQUENCE public.users_id_seq TO role_admin;


--
-- Name: TABLE v_category_stats; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.v_category_stats TO role_analyst;
GRANT ALL ON TABLE public.v_category_stats TO role_admin;


--
-- Name: TABLE v_sales_details; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.v_sales_details TO role_analyst;
GRANT ALL ON TABLE public.v_sales_details TO role_admin;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT ON TABLES  TO role_analyst;


--
-- PostgreSQL database dump complete
--

\unrestrict Gtidh4cSMUK3lhWCawrDgp7RzOdy5UjtKj2DCJ7eN0AKwLbjMKgL04Ar2r5J9Br

