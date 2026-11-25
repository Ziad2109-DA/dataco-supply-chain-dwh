
USE DataCo_DWH;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'SILVER')
    EXEC('CREATE SCHEMA SILVER');
GO

DROP TABLE IF EXISTS SILVER.Customers;
GO

--customers_silver
WITH src AS (
    SELECT
        TRY_CAST(Customer_Id AS INT)                                  AS customer_id,
        NULLIF(LTRIM(RTRIM(Customer_Fname)), '')                      AS fname,
        NULLIF(LTRIM(RTRIM(Customer_Lname)), '')                      AS lname,
        NULLIF(LTRIM(RTRIM(Customer_Segment)), '')                    AS customer_segment,
        NULLIF(LTRIM(RTRIM(Customer_Street)), '')                     AS street,
        NULLIF(LTRIM(RTRIM(Customer_City)), '')                       AS city,
        NULLIF(LTRIM(RTRIM(Customer_State)), '')                      AS state,
        NULLIF(LTRIM(RTRIM(Customer_Zipcode)), '')                    AS zipcode,
        NULLIF(LTRIM(RTRIM(Customer_Country)), '')                    AS country,
        TRY_CAST(Latitude  AS DECIMAL(9,6))                           AS latitude,
        TRY_CAST(Longitude AS DECIMAL(9,6))                           AS longitude,
        ROW_NUMBER() OVER (PARTITION BY Customer_Id ORDER BY (SELECT NULL)) AS rn
    FROM BRONZE.Customers
)
SELECT
    customer_id,
    fname AS customer_fname,
    lname AS customer_lname,
    LTRIM(RTRIM(CONCAT(fname, ' ', lname)))                           AS customer_full_name,
    customer_segment,
    street AS customer_street,
    city   AS customer_city,
    state  AS customer_state,
    zipcode AS customer_zipcode,
    country AS customer_country,
    CONCAT_WS(', ', street, city, state, zipcode, country)            AS customer_full_address,
    latitude,
    longitude
INTO SILVER.Customers
FROM src
WHERE rn = 1;
GO

-- Check
SELECT COUNT(*) AS cnt FROM SILVER.Customers;           
SELECT TOP 5 customer_id, customer_full_name, customer_full_address FROM SILVER.Customers;
SELECT COUNT(*) AS blank_names FROM SILVER.Customers WHERE customer_full_name = '';
GO

--Products_silver
SELECT MIN(TRY_CAST(Product_Price AS DECIMAL(18,2))) AS min_price,
       MAX(TRY_CAST(Product_Price AS DECIMAL(18,2))) AS max_price,
       AVG(TRY_CAST(Product_Price AS DECIMAL(18,2))) AS avg_price
FROM BRONZE.Products;
GO

DROP TABLE IF EXISTS SILVER.Products;
GO

WITH src AS (
    SELECT
        TRY_CAST(Product_Card_Id AS INT)                  AS product_card_id,
        NULLIF(LTRIM(RTRIM(Product_Name)), '')            AS product_name,
        TRY_CAST(Product_Price AS DECIMAL(18,2))          AS product_price,
        TRY_CAST(Product_Status AS INT)                   AS product_status,
        TRY_CAST(Category_Id AS INT)                      AS category_id,
        NULLIF(LTRIM(RTRIM(Category_Name)), '')           AS category_name,
        TRY_CAST(Department_Id AS INT)                    AS department_id,
        NULLIF(LTRIM(RTRIM(Department_Name)), '')         AS department_name,
        ROW_NUMBER() OVER (PARTITION BY Product_Card_Id ORDER BY (SELECT NULL)) AS rn
    FROM BRONZE.Products
),
dedup AS (
    SELECT * FROM src WHERE rn = 1
),
cutoffs AS (
    SELECT DISTINCT
        PERCENTILE_CONT(0.3333) WITHIN GROUP (ORDER BY product_price) OVER () AS p33,
        PERCENTILE_CONT(0.6667) WITHIN GROUP (ORDER BY product_price) OVER () AS p66
    FROM dedup
)
SELECT
    d.product_card_id, d.product_name, d.product_price, d.product_status,
    d.category_id, d.category_name, d.department_id, d.department_name,
    CASE
        WHEN d.product_price <= c.p33 THEN 'Low'
        WHEN d.product_price <= c.p66 THEN 'Medium'
        ELSE 'High'
    END AS price_tier
INTO SILVER.Products
FROM dedup d CROSS JOIN cutoffs c;
GO

-- Check
SELECT COUNT(*) AS cnt FROM SILVER.Products;             -- = 118
SELECT price_tier, COUNT(*) AS cnt, MIN(product_price) AS min_p, MAX(product_price) AS max_p
FROM SILVER.Products GROUP BY price_tier ORDER BY min_p;
GO

--Orders_silver
DROP TABLE IF EXISTS SILVER.Orders;
GO

WITH src AS (
    SELECT
        TRY_CAST(Order_Id AS INT)                              AS order_id,
        TRY_CAST(Order_Item_Id AS INT)                         AS order_item_id,
        TRY_CAST(Customer_Id AS INT)                           AS customer_id,
        TRY_CAST(Product_Card_Id AS INT)                       AS product_card_id,
        TRY_CAST(salesman_id AS INT)                           AS salesman_id,

        REPLACE(REPLACE(LTRIM(RTRIM(Type)), '  ', ' '), '  ', ' ')           AS payment_type,
        CASE UPPER(REPLACE(REPLACE(LTRIM(RTRIM(Market)), '  ', ' '), '  ', ' '))
    WHEN 'EUROPE'        THEN 'Europe'
    WHEN 'EU'            THEN 'Europe'
    WHEN 'LATAM'         THEN 'LATAM'
    WHEN 'LATIN AMERICA' THEN 'LATAM'
    WHEN 'PACIFIC ASIA'  THEN 'Pacific Asia'
    WHEN 'ASIA-PACIFIC'  THEN 'Pacific Asia'
    WHEN 'APAC'          THEN 'Pacific Asia'
    WHEN 'USCA'          THEN 'USCA'
    WHEN 'U.S.-CANADA'   THEN 'USCA'
    WHEN 'US AND CANADA' THEN 'USCA'
    WHEN 'US & CANADA'   THEN 'USCA'
    WHEN 'AFRICA'        THEN 'Africa'
    WHEN 'AFR'           THEN 'Africa'
    ELSE REPLACE(REPLACE(LTRIM(RTRIM(Market)), '  ', ' '), '  ', ' ')
END                                                                  AS market,
        REPLACE(REPLACE(LTRIM(RTRIM(Order_Region)), '  ', ' '), '  ', ' ')   AS order_region,
        REPLACE(REPLACE(LTRIM(RTRIM(Order_State)), '  ', ' '), '  ', ' ')    AS order_state,
        REPLACE(REPLACE(LTRIM(RTRIM(Order_Status)), '  ', ' '), '  ', ' ')   AS order_status,
        CASE UPPER(REPLACE(REPLACE(LTRIM(RTRIM(Shipping_Mode)), '  ', ' '), '  ', ' '))
    WHEN 'STANDARD CLASS' THEN 'Standard Class'
    WHEN 'STANDARD'       THEN 'Standard Class'
    WHEN 'STD CLASS'      THEN 'Standard Class'
    WHEN 'SECOND CLASS'   THEN 'Second Class'
    WHEN '2ND CLASS'      THEN 'Second Class'
    WHEN 'FIRST CLASS'    THEN 'First Class'
    WHEN '1ST CLASS'      THEN 'First Class'
    WHEN 'SAME DAY'       THEN 'Same Day'
    WHEN 'SAME-DAY'       THEN 'Same Day'
    ELSE REPLACE(REPLACE(LTRIM(RTRIM(Shipping_Mode)), '  ', ' '), '  ', ' ')
END                                                                  AS shipping_mode,
        NULLIF(LTRIM(RTRIM(Order_Zipcode)), '')                              AS order_zipcode,

        UPPER(LEFT(REPLACE(REPLACE(LTRIM(RTRIM(Delivery_Status)), '  ', ' '), '  ', ' '), 1))
          + LOWER(SUBSTRING(REPLACE(REPLACE(LTRIM(RTRIM(Delivery_Status)), '  ', ' '), '  ', ' '), 2, 100))
                                                                            AS delivery_status,

        TRY_CAST(Late_delivery_risk AS INT)                    AS late_delivery_risk,
        TRY_CONVERT(DATETIME, order_date_DateOrders, 101)      AS order_date,
        TRY_CONVERT(DATETIME, shipping_date_DateOrders, 101)   AS shipping_date,
        TRY_CAST(Days_for_shipping_real AS INT)                AS days_shipping_real,
        TRY_CAST(Days_for_shipment_scheduled AS INT)           AS days_shipping_scheduled,

        TRY_CAST(Order_Item_Quantity AS INT)                   AS quantity,
        TRY_CAST(Order_Item_Discount AS DECIMAL(18,4))         AS discount,
        TRY_CAST(Order_Item_Total AS DECIMAL(18,4))            AS order_item_total,
        TRY_CAST(Benefit_per_order AS DECIMAL(18,4))           AS profit,
        TRY_CAST(Order_Item_Profit_Ratio AS DECIMAL(18,4))     AS profit_ratio,

        ROW_NUMBER() OVER (PARTITION BY Order_Item_Id ORDER BY (SELECT NULL)) AS rn
    FROM BRONZE.Orders
)
SELECT
    o.order_id,
    o.order_item_id,
    o.customer_id,
    o.product_card_id,
    o.salesman_id,
    o.payment_type, o.market, o.order_region, o.order_state, o.order_zipcode,
    o.order_status, o.shipping_mode, o.delivery_status,
    o.order_date, o.shipping_date,
    YEAR(o.order_date)  AS order_year,
    MONTH(o.order_date) AS order_month,
    o.days_shipping_real,
    o.days_shipping_scheduled,
    o.days_shipping_real - o.days_shipping_scheduled        AS shipping_delay_days,
    CASE WHEN o.delivery_status = 'Late delivery' THEN 1 ELSE 0 END AS is_late_delivery,
    o.late_delivery_risk,
    o.quantity,
    p.product_price                                         AS list_unit_price,      -- من Products
    CASE WHEN o.quantity > 0
         THEN CAST(o.order_item_total / o.quantity AS DECIMAL(18,4)) END AS paid_unit_price,  -- Total ÷ Qty
    o.discount,
    o.order_item_total,
    CAST(o.quantity * p.product_price AS DECIMAL(18,4))     AS gross_revenue,        -- Qty × list price
    o.order_item_total                                      AS line_item_revenue,    -- الإيراد الفعلي
    o.profit,
    o.profit_ratio
INTO SILVER.Orders
FROM src o
LEFT JOIN SILVER.Products p ON p.product_card_id = o.product_card_id
WHERE o.rn = 1;
GO

--Check
SELECT COUNT(*) AS cnt FROM SILVER.Orders;                            

SELECT delivery_status, COUNT(*) AS cnt                               
FROM SILVER.Orders GROUP BY delivery_status ORDER BY cnt DESC;


SELECT
    SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END)           AS null_order_date,
    SUM(CASE WHEN shipping_date IS NULL THEN 1 ELSE 0 END)        AS null_ship_date,
    SUM(CASE WHEN quantity IS NULL THEN 1 ELSE 0 END)             AS null_qty,
    SUM(CASE WHEN list_unit_price IS NULL THEN 1 ELSE 0 END)      AS null_list_price
FROM SILVER.Orders;



SELECT is_late_delivery, late_delivery_risk, COUNT(*) AS cnt
FROM SILVER.Orders GROUP BY is_late_delivery, late_delivery_risk
ORDER BY is_late_delivery, late_delivery_risk;


SELECT
    SUM(CASE WHEN ABS(gross_revenue - discount - order_item_total) < 0.01 THEN 1 ELSE 0 END) AS matches,
    SUM(CASE WHEN ABS(gross_revenue - discount - order_item_total) >= 0.01 THEN 1 ELSE 0 END) AS mismatches
FROM SILVER.Orders;


SELECT
    SUM(CASE WHEN ABS(gross_revenue - order_item_total) < 0.01 THEN 1 ELSE 0 END) AS equals_gross,
    COUNT(*) AS total_rows
FROM SILVER.Orders;
GO