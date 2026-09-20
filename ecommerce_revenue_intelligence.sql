-- ============================================================
-- E-Commerce Customer & Revenue Intelligence
-- Dataset: Olist Brazilian E-Commerce (Kaggle)
-- Database: ecommerce_revenue_intelligence
-- Author: Prince Mahendra Sharma
-- ============================================================
-- Tools: MySQL 8.0
-- Method: LOAD DATA INFILE with manual schema design (primary
-- keys, foreign keys, and appropriate data types set explicitly
-- rather than relying on auto-detect import).
-- ============================================================


-- ============================================================
-- SECTION 1: SCHEMA SETUP
-- ============================================================
-- 8 tables, loaded in dependency order (parent tables before
-- any table that references them via foreign key).

CREATE DATABASE ecommerce_revenue_intelligence;
USE ecommerce_revenue_intelligence;

CREATE TABLE customers (
    customer_id VARCHAR(32),
    customer_unique_id VARCHAR(32),
    customer_zip_code_prefix INT,
    customer_city VARCHAR(36),
    customer_state VARCHAR(2),
    PRIMARY KEY (customer_id)
);

CREATE TABLE category_translation (
    product_category_name VARCHAR(50),
    product_category_name_english VARCHAR(50),
    PRIMARY KEY (product_category_name)
);

CREATE TABLE products (
    product_id VARCHAR(32),
    product_category_name VARCHAR(50),
    product_name_lenght INT,
    product_description_lenght INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT,
    PRIMARY KEY (product_id),
    FOREIGN KEY (product_category_name) REFERENCES category_translation(product_category_name)
);

CREATE TABLE sellers (
    seller_id VARCHAR(32),
    seller_zip_code_prefix INT,
    seller_city VARCHAR(50),
    seller_state VARCHAR(2),
    PRIMARY KEY (seller_id)
);

CREATE TABLE orders (
    order_id VARCHAR(32),
    customer_id VARCHAR(32),
    order_status VARCHAR(15),
    order_purchase_timestamp DATETIME,
    order_approved_at DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATE,
    PRIMARY KEY (order_id),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
    order_id VARCHAR(32),
    order_item_id INT,
    product_id VARCHAR(32),
    seller_id VARCHAR(32),
    shipping_limit_date DATETIME,
    price DECIMAL(10,2),
    freight_value DECIMAL(10,2),
    PRIMARY KEY (order_id, order_item_id),
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    FOREIGN KEY (seller_id) REFERENCES sellers(seller_id)
);

CREATE TABLE payments (
    order_id VARCHAR(32),
    payment_sequential INT,
    payment_type VARCHAR(20),
    payment_installments INT,
    payment_value DECIMAL(10,2),
    PRIMARY KEY (order_id, payment_sequential),
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

CREATE TABLE reviews (
    review_id VARCHAR(32),
    order_id VARCHAR(32),
    review_score INT,
    review_comment_title VARCHAR(100),
    review_comment_message TEXT,
    review_creation_date DATETIME,
    review_answer_timestamp DATETIME,
    PRIMARY KEY (review_id),
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);


-- ============================================================
-- SECTION 2: DATA LOADING
-- ============================================================
-- Source files are comma-separated, double-quote enclosed.
-- Load order matters: parent tables must be loaded before any
-- child table that references them via foreign key.
--
-- Data-cleaning notes (found during load, handled explicitly):
--   1. Two product categories present in products.csv had no
--      entry in the category translation file (pc_gamer,
--      portateis_cozinha_e_preparadores_de_alimentos). Manually
--      added English translations rather than dropping those
--      products.
--   2. Several numeric/date fields (product dimensions, order
--      delivery dates) contain blank values in the source files.
--      Loaded using NULLIF(@var, '') so blanks become proper
--      NULLs instead of failing the load or inserting invalid
--      zero/empty values.
--   3. reviews.csv contains 814 duplicate review_id values.
--      Loaded using LOAD DATA ... IGNORE so duplicates are
--      skipped rather than breaking the primary key.

-- Example load pattern (repeated per table, paths omitted here
-- since they're local to the machine used for this project):

-- LOAD DATA INFILE '<path>/olist_customers_dataset.csv'
-- INTO TABLE customers
-- FIELDS TERMINATED BY ','
-- ENCLOSED BY '"'
-- IGNORE 1 ROWS;

-- Products load (blank numeric fields + 2 missing categories handled):
-- LOAD DATA INFILE '<path>/olist_products_dataset.csv'
-- INTO TABLE products
-- FIELDS TERMINATED BY ',' ENCLOSED BY '"' IGNORE 1 ROWS
-- (product_id, @cat, @v1, @v2, @v3, @v4, @v5, @v6, @v7)
-- SET
--   product_category_name = NULLIF(@cat, ''),
--   product_name_lenght = NULLIF(@v1, ''),
--   product_description_lenght = NULLIF(@v2, ''),
--   product_photos_qty = NULLIF(@v3, ''),
--   product_weight_g = NULLIF(@v4, ''),
--   product_length_cm = NULLIF(@v5, ''),
--   product_height_cm = NULLIF(@v6, ''),
--   product_width_cm = NULLIF(@v7, '');

-- Orders load (blank delivery dates handled):
-- LOAD DATA INFILE '<path>/olist_orders_dataset.csv'
-- INTO TABLE orders
-- FIELDS TERMINATED BY ',' ENCLOSED BY '"' IGNORE 1 ROWS
-- (order_id, customer_id, order_status, @v1, @v2, @v3, @v4, order_estimated_delivery_date)
-- SET
--   order_purchase_timestamp = NULLIF(@v1, ''),
--   order_approved_at = NULLIF(@v2, ''),
--   order_delivered_carrier_date = NULLIF(@v3, ''),
--   order_delivered_customer_date = NULLIF(@v4, '');

-- Reviews load (duplicate review_id values skipped):
-- LOAD DATA INFILE '<path>/olist_order_reviews_dataset.csv'
-- IGNORE INTO TABLE reviews
-- FIELDS TERMINATED BY ',' ENCLOSED BY '"' IGNORE 1 ROWS;

INSERT INTO category_translation (product_category_name, product_category_name_english)
VALUES
    ('pc_gamer', 'gaming_pc'),
    ('portateis_cozinha_e_preparadores_de_alimentos', 'kitchen_appliances');


-- ============================================================
-- SECTION 3: DATA VALIDATION
-- ============================================================
-- Row counts confirmed after load: customers 99,441 |
-- category_translation 73 | products 32,951 | sellers 3,095 |
-- orders 99,441 | order_items 112,650 | payments 103,886 |
-- reviews 98,409.

SELECT
    (SELECT COUNT(*) FROM customers) AS customers,
    (SELECT COUNT(*) FROM category_translation) AS category_translation,
    (SELECT COUNT(*) FROM products) AS products,
    (SELECT COUNT(*) FROM sellers) AS sellers,
    (SELECT COUNT(*) FROM orders) AS orders,
    (SELECT COUNT(*) FROM order_items) AS order_items,
    (SELECT COUNT(*) FROM payments) AS payments,
    (SELECT COUNT(*) FROM reviews) AS reviews;


-- ============================================================
-- SECTION 4: CUSTOMER & REVENUE ANALYSIS
-- ============================================================

-- ------------------------------------------------------------
-- Q1: Who are the highest-value customers, and how often do
-- they buy? (total orders + total spend per unique customer)
-- ------------------------------------------------------------
-- Note: customer_id is generated per order in this dataset, not
-- per person -- customer_unique_id is the real customer
-- identifier and is used here. payment_value is summed per
-- order first via COUNT(DISTINCT) to avoid inflating totals
-- from split payments.
SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(p.payment_value) AS total_spent
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id
INNER JOIN payments p ON o.order_id = p.order_id
GROUP BY c.customer_unique_id
ORDER BY total_spent DESC
LIMIT 10;

-- Finding: only ~3.1% of customers (2,997 of 96,096) placed more
-- than one order. This is a one-time-purchase-dominated business,
-- which is why the analysis below focuses on revenue concentration
-- and delivery experience rather than repeat-purchase metrics
-- (RFM / cohort retention / CLV are not well supported by this
-- purchase pattern).


-- ------------------------------------------------------------
-- Q2: How concentrated is revenue -- what % of total revenue
-- comes from the top 10% of orders by value?
-- ------------------------------------------------------------
-- Note: revenue is scoped to delivered orders only (cancelled /
-- unavailable orders are excluded, since a payment tied to a
-- cancelled order isn't real revenue).
WITH order_totals AS (
    SELECT p.order_id, SUM(p.payment_value) AS total_payment
    FROM payments p
    INNER JOIN orders o ON p.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY p.order_id
),
ranked_orders AS (
    SELECT
        order_id,
        total_payment,
        ROW_NUMBER() OVER (ORDER BY total_payment DESC) AS rank_num,
        COUNT(*) OVER () AS total_orders
    FROM order_totals
)
SELECT
    SUM(CASE WHEN rank_num <= total_orders * 0.10 THEN total_payment ELSE 0 END) AS top_10_pct_revenue,
    SUM(total_payment) AS total_revenue,
    ROUND(
        SUM(CASE WHEN rank_num <= total_orders * 0.10 THEN total_payment ELSE 0 END)
        / SUM(total_payment) * 100
    , 2) AS pct_of_revenue
FROM ranked_orders;

-- Finding: the top 10% of orders account for 38.05% of total
-- (delivered-order) revenue of R$15,422,461.77.


-- ------------------------------------------------------------
-- Q3: Which product categories drive the most revenue?
-- ------------------------------------------------------------
-- Note: scoped to delivered orders only, same reasoning as Q2.
WITH category_revenue AS (
    SELECT
        ct.product_category_name_english,
        SUM(oi.price) AS total_revenue
    FROM order_items oi
    INNER JOIN orders o ON oi.order_id = o.order_id
    INNER JOIN products pd ON oi.product_id = pd.product_id
    INNER JOIN category_translation ct ON pd.product_category_name = ct.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY ct.product_category_name_english
),
with_grand_total AS (
    SELECT
        product_category_name_english,
        total_revenue,
        SUM(total_revenue) OVER () AS grand_total
    FROM category_revenue
)
SELECT
    product_category_name_english,
    total_revenue,
    grand_total,
    ROUND((total_revenue / grand_total) * 100, 2) AS pct_of_revenue
FROM with_grand_total
ORDER BY total_revenue DESC
LIMIT 10;

-- Finding: health_beauty leads at 9.45% of revenue; no single
-- category dominates, so the order-level concentration in Q2 is
-- spread across many categories rather than one blockbuster line.


-- ------------------------------------------------------------
-- Q4: Does late delivery affect customer satisfaction?
-- ------------------------------------------------------------
SELECT
    AVG(r.review_score) AS avg_review_score,
    CASE
        WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 'on_time'
        ELSE 'late'
    END AS delivery_status
FROM orders o
INNER JOIN reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY delivery_status;

-- Finding: on-time deliveries average 4.30 stars vs. 2.57 for
-- late deliveries -- a ~40% drop in review score.


-- ------------------------------------------------------------
-- Q5: How widespread is the late-delivery problem?
-- ------------------------------------------------------------
SELECT
    COUNT(*) AS total_delivered,
    SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1 ELSE 0 END) AS late_count,
    ROUND(
        SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
    , 2) AS late_pct
FROM orders
WHERE order_status = 'delivered';

-- Finding: 8.11% of delivered orders arrive late -- a relatively
-- small share, but paired with Q4's score drop, this is a
-- meaningful driver of poor reviews in a business with almost no
-- repeat customers to win back.


-- ------------------------------------------------------------
-- Q6: Which customer states generate the most revenue?
-- ------------------------------------------------------------
-- Note: scoped to delivered orders only, same reasoning as Q2.
WITH state_revenue AS (
    SELECT
        c.customer_state,
        SUM(oi.price) AS total_revenue
    FROM orders o
    INNER JOIN customers c ON o.customer_id = c.customer_id
    INNER JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_state
),
with_grand_total AS (
    SELECT
        customer_state,
        total_revenue,
        SUM(total_revenue) OVER () AS grand_total
    FROM state_revenue
)
SELECT
    customer_state,
    total_revenue,
    grand_total,
    ROUND((total_revenue / grand_total) * 100, 2) AS pct_of_revenue
FROM with_grand_total
ORDER BY total_revenue DESC
LIMIT 10;

-- Finding: Sao Paulo (SP) alone drives 38.33% of total revenue --
-- more than the next three states (RJ, MG, RS) combined.


-- ------------------------------------------------------------
-- Q7: Do customers use more installments for bigger purchases?
-- ------------------------------------------------------------
WITH order_summary AS (
    SELECT
        order_id,
        MAX(payment_installments) AS max_installments,
        SUM(payment_value) AS order_value
    FROM payments
    GROUP BY order_id
),
bucketed_orders AS (
    SELECT
        order_id,
        order_value,
        CASE
            WHEN max_installments = 1 THEN '1 (Direct)'
            WHEN max_installments BETWEEN 2 AND 3 THEN '2-3'
            WHEN max_installments BETWEEN 4 AND 6 THEN '4-6'
            WHEN max_installments BETWEEN 7 AND 12 THEN '7-12'
            ELSE '12+'
        END AS installment_bucket
    FROM order_summary
)
SELECT
    installment_bucket,
    COUNT(*) AS order_count,
    ROUND(AVG(order_value), 2) AS avg_order_value
FROM bucketed_orders
GROUP BY installment_bucket
ORDER BY MIN(CASE
    WHEN installment_bucket = '1 (Direct)' THEN 1
    WHEN installment_bucket = '2-3' THEN 2
    WHEN installment_bucket = '4-6' THEN 3
    WHEN installment_bucket = '7-12' THEN 4
    ELSE 5
END);

-- Finding: average order value rises steadily with installment
-- count, from Rs.121 (paid in full) up to Rs.413 (12+ installments)
-- -- confirming installments are used mainly for larger purchases.
