
USE DataCo_DWH;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'GOLD')
    EXEC('CREATE SCHEMA GOLD');
GO

DROP TABLE IF EXISTS GOLD.FactOrders;
DROP TABLE IF EXISTS GOLD.DimDate;
DROP TABLE IF EXISTS GOLD.DimCustomer;
DROP TABLE IF EXISTS GOLD.DimProduct;
DROP TABLE IF EXISTS GOLD.DimShipping;
DROP TABLE IF EXISTS GOLD.DimMarket;
GO


CREATE TABLE GOLD.DimDate (
    date_key      INT          NOT NULL,   -- yyyymmdd
    full_date     DATE         NOT NULL,
    [year]        SMALLINT     NOT NULL,
    [quarter]     TINYINT      NOT NULL,
    [month]       TINYINT      NOT NULL,
    month_name    VARCHAR(10)  NOT NULL,
    year_month    CHAR(7)      NOT NULL,   -- 2017-03
    [day]         TINYINT      NOT NULL,
    day_of_week   TINYINT      NOT NULL,   -- 1 = Monday
    day_name      VARCHAR(10)  NOT NULL,
    is_weekend    BIT          NOT NULL,
    CONSTRAINT PK_DimDate PRIMARY KEY CLUSTERED (date_key)
);
GO

DECLARE @start DATE, @end DATE;
SELECT @start = CAST(MIN(order_date)    AS DATE),
       @end   = CAST(MAX(shipping_date) AS DATE)
FROM SILVER.Orders;


SET @start = DATEFROMPARTS(YEAR(@start), 1, 1);
SET @end   = DATEFROMPARTS(YEAR(@end), 12, 31);

;WITH d AS (
    SELECT @start AS dt
    UNION ALL
    SELECT DATEADD(DAY, 1, dt) FROM d WHERE dt < @end
)
INSERT INTO GOLD.DimDate
SELECT
    CONVERT(INT, FORMAT(dt, 'yyyyMMdd')),
    dt,
    YEAR(dt),
    DATEPART(QUARTER, dt),
    MONTH(dt),
    DATENAME(MONTH, dt),
    FORMAT(dt, 'yyyy-MM'),
    DAY(dt),
    ((DATEPART(WEEKDAY, dt) + @@DATEFIRST - 2) % 7) + 1,   -- 1 = Monday بغض النظر عن إعداد DATEFIRST
    DATENAME(WEEKDAY, dt),
    CASE WHEN ((DATEPART(WEEKDAY, dt) + @@DATEFIRST - 2) % 7) + 1 IN (6,7) THEN 1 ELSE 0 END
FROM d
OPTION (MAXRECURSION 0);
GO

--DimCustomers
CREATE TABLE GOLD.DimCustomer (
    customer_key          INT IDENTITY(1,1) NOT NULL,
    customer_id           INT           NOT NULL,   -- business key
    customer_full_name    NVARCHAR(200) NULL,
    customer_segment      NVARCHAR(50)  NULL,
    customer_city         NVARCHAR(100) NULL,
    customer_state        NVARCHAR(100) NULL,
    customer_country      NVARCHAR(100) NULL,
    customer_zipcode      NVARCHAR(20)  NULL,
    customer_full_address NVARCHAR(500) NULL,
    latitude              DECIMAL(9,6)  NULL,
    longitude             DECIMAL(9,6)  NULL,
    CONSTRAINT PK_DimCustomer PRIMARY KEY CLUSTERED (customer_key),
    CONSTRAINT UQ_DimCustomer_id UNIQUE (customer_id)
);
GO

INSERT INTO GOLD.DimCustomer
    (customer_id, customer_full_name, customer_segment, customer_city, customer_state,
     customer_country, customer_zipcode, customer_full_address, latitude, longitude)
SELECT customer_id, customer_full_name, customer_segment, customer_city, customer_state,
       customer_country, customer_zipcode, customer_full_address, latitude, longitude
FROM SILVER.Customers;
GO

--DimProduct
CREATE TABLE GOLD.DimProduct (
    product_key      INT IDENTITY(1,1) NOT NULL,
    product_card_id  INT            NOT NULL,   -- business key
    product_name     NVARCHAR(200)  NULL,
    product_price    DECIMAL(18,2)  NULL,
    price_tier       VARCHAR(10)    NULL,
    product_status   INT            NULL,
    category_id      INT            NULL,
    category_name    NVARCHAR(100)  NULL,
    department_id    INT            NULL,
    department_name  NVARCHAR(100)  NULL,
    CONSTRAINT PK_DimProduct PRIMARY KEY CLUSTERED (product_key),
    CONSTRAINT UQ_DimProduct_id UNIQUE (product_card_id)
);
GO

INSERT INTO GOLD.DimProduct
    (product_card_id, product_name, product_price, price_tier, product_status,
     category_id, category_name, department_id, department_name)
SELECT product_card_id, product_name, product_price, price_tier, product_status,
       category_id, category_name, department_id, department_name
FROM SILVER.Products;
GO

--DimShipping
CREATE TABLE GOLD.DimShipping (
    shipping_key     INT IDENTITY(1,1) NOT NULL,
    shipping_mode    NVARCHAR(50) NOT NULL,
    delivery_status  NVARCHAR(50) NOT NULL,
    order_status     NVARCHAR(50) NOT NULL,
    payment_type     NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_DimShipping PRIMARY KEY CLUSTERED (shipping_key),
    CONSTRAINT UQ_DimShipping UNIQUE (shipping_mode, delivery_status, order_status, payment_type)
);
GO

INSERT INTO GOLD.DimShipping (shipping_mode, delivery_status, order_status, payment_type)
SELECT DISTINCT
    ISNULL(shipping_mode, 'Unknown'),
    ISNULL(delivery_status, 'Unknown'),
    ISNULL(order_status, 'Unknown'),
    ISNULL(payment_type, 'Unknown')
FROM SILVER.Orders;
GO

--DimMarket
CREATE TABLE GOLD.DimMarket (
    market_key    INT IDENTITY(1,1) NOT NULL,
    market        NVARCHAR(50)  NOT NULL,
    order_region  NVARCHAR(100) NOT NULL,
    order_state   NVARCHAR(100) NOT NULL,
    CONSTRAINT PK_DimMarket PRIMARY KEY CLUSTERED (market_key),
    CONSTRAINT UQ_DimMarket UNIQUE (market, order_region, order_state)
);
GO

INSERT INTO GOLD.DimMarket (market, order_region, order_state)
SELECT DISTINCT
    ISNULL(market, 'Unknown'),
    ISNULL(order_region, 'Unknown'),
    ISNULL(order_state, 'Unknown')
FROM SILVER.Orders;
GO

--FactOrders
CREATE TABLE GOLD.FactOrders (
    order_item_id          INT           NOT NULL,   -- PK
    order_id               INT           NOT NULL,   -- degenerate dimension
    order_date_key         INT           NOT NULL,
    shipping_date_key      INT           NULL,
    customer_key           INT           NOT NULL,
    product_key            INT           NOT NULL,
    shipping_key           INT           NOT NULL,
    market_key             INT           NOT NULL,

    quantity               INT           NULL,
    list_unit_price        DECIMAL(18,4) NULL,
    paid_unit_price        DECIMAL(18,4) NULL,
    discount               DECIMAL(18,4) NULL,
    gross_revenue          DECIMAL(18,4) NULL,
    line_item_revenue      DECIMAL(18,4) NULL,
    profit                 DECIMAL(18,4) NULL,
    profit_ratio           DECIMAL(18,4) NULL,
    days_shipping_real     INT           NULL,
    days_shipping_scheduled INT          NULL,
    shipping_delay_days    INT           NULL,
    is_late_delivery       BIT           NOT NULL,

    CONSTRAINT PK_FactOrders PRIMARY KEY CLUSTERED (order_item_id),
    CONSTRAINT FK_Fact_OrderDate  FOREIGN KEY (order_date_key)    REFERENCES GOLD.DimDate(date_key),
    CONSTRAINT FK_Fact_ShipDate   FOREIGN KEY (shipping_date_key) REFERENCES GOLD.DimDate(date_key),
    CONSTRAINT FK_Fact_Customer   FOREIGN KEY (customer_key)      REFERENCES GOLD.DimCustomer(customer_key),
    CONSTRAINT FK_Fact_Product    FOREIGN KEY (product_key)       REFERENCES GOLD.DimProduct(product_key),
    CONSTRAINT FK_Fact_Shipping   FOREIGN KEY (shipping_key)      REFERENCES GOLD.DimShipping(shipping_key),
    CONSTRAINT FK_Fact_Market     FOREIGN KEY (market_key)        REFERENCES GOLD.DimMarket(market_key)
);
GO

INSERT INTO GOLD.FactOrders
SELECT
    o.order_item_id,
    o.order_id,
    CONVERT(INT, FORMAT(o.order_date, 'yyyyMMdd')),
    CASE WHEN o.shipping_date IS NULL THEN NULL
         ELSE CONVERT(INT, FORMAT(o.shipping_date, 'yyyyMMdd')) END,
    c.customer_key,
    p.product_key,
    s.shipping_key,
    m.market_key,
    o.quantity,
    o.list_unit_price,
    o.paid_unit_price,
    o.discount,
    o.gross_revenue,
    o.line_item_revenue,
    o.profit,
    o.profit_ratio,
    o.days_shipping_real,
    o.days_shipping_scheduled,
    o.shipping_delay_days,
    o.is_late_delivery
FROM SILVER.Orders o
JOIN GOLD.DimCustomer c ON c.customer_id     = o.customer_id
JOIN GOLD.DimProduct  p ON p.product_card_id = o.product_card_id
JOIN GOLD.DimShipping s ON s.shipping_mode   = ISNULL(o.shipping_mode, 'Unknown')
                       AND s.delivery_status = ISNULL(o.delivery_status, 'Unknown')
                       AND s.order_status    = ISNULL(o.order_status, 'Unknown')
                       AND s.payment_type    = ISNULL(o.payment_type, 'Unknown')
JOIN GOLD.DimMarket   m ON m.market          = ISNULL(o.market, 'Unknown')
                       AND m.order_region    = ISNULL(o.order_region, 'Unknown')
                       AND m.order_state     = ISNULL(o.order_state, 'Unknown');
GO


CREATE NONCLUSTERED INDEX IX_Fact_OrderDate ON GOLD.FactOrders (order_date_key);
CREATE NONCLUSTERED INDEX IX_Fact_ShipDate  ON GOLD.FactOrders (shipping_date_key);
CREATE NONCLUSTERED INDEX IX_Fact_Customer  ON GOLD.FactOrders (customer_key);
CREATE NONCLUSTERED INDEX IX_Fact_Product   ON GOLD.FactOrders (product_key);
CREATE NONCLUSTERED INDEX IX_Fact_Shipping  ON GOLD.FactOrders (shipping_key);
CREATE NONCLUSTERED INDEX IX_Fact_Market    ON GOLD.FactOrders (market_key);
CREATE NONCLUSTERED INDEX IX_Fact_OrderId   ON GOLD.FactOrders (order_id);
GO



SELECT (SELECT COUNT(*) FROM SILVER.Orders)  AS silver_rows,
       (SELECT COUNT(*) FROM GOLD.FactOrders) AS fact_rows;


SELECT 'DimDate' AS tbl, COUNT(*) AS cnt FROM GOLD.DimDate
UNION ALL SELECT 'DimCustomer', COUNT(*) FROM GOLD.DimCustomer
UNION ALL SELECT 'DimProduct',  COUNT(*) FROM GOLD.DimProduct
UNION ALL SELECT 'DimShipping', COUNT(*) FROM GOLD.DimShipping
UNION ALL SELECT 'DimMarket',   COUNT(*) FROM GOLD.DimMarket;


SELECT (SELECT SUM(line_item_revenue) FROM SILVER.Orders)   AS silver_revenue,
       (SELECT SUM(line_item_revenue) FROM GOLD.FactOrders) AS gold_revenue,
       (SELECT SUM(profit) FROM SILVER.Orders)              AS silver_profit,
       (SELECT SUM(profit) FROM GOLD.FactOrders)            AS gold_profit;


SELECT
    SUM(CASE WHEN order_date_key IS NULL THEN 1 ELSE 0 END) AS null_order_date,
    SUM(CASE WHEN shipping_date_key IS NULL THEN 1 ELSE 0 END) AS null_ship_date
FROM GOLD.FactOrders;


SELECT COUNT(*) AS missing_in_dimdate
FROM GOLD.FactOrders f
LEFT JOIN GOLD.DimDate d ON d.date_key = f.order_date_key
WHERE d.date_key IS NULL;


SELECT m.market,
       COUNT(*) AS items,
       CAST(100.0 * SUM(CAST(f.is_late_delivery AS INT)) / COUNT(*) AS DECIMAL(5,2)) AS late_pct
FROM GOLD.FactOrders f
JOIN GOLD.DimMarket m ON m.market_key = f.market_key
GROUP BY m.market
ORDER BY late_pct DESC;
GO

USE DataCo_DWH;
GO
ALTER AUTHORIZATION ON DATABASE::DataCo_DWH TO sa;
GO