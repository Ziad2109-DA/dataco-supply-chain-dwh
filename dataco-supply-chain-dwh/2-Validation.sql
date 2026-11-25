
USE DataCo_DWH;
GO


SELECT 'Orders' AS tbl, COUNT(*) AS cnt FROM BRONZE.Orders
UNION ALL SELECT 'Customers', COUNT(*) FROM BRONZE.Customers
UNION ALL SELECT 'Products',  COUNT(*) FROM BRONZE.Products;


-- Orders
SELECT
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(Order_Item_Id)),'')  IS NULL THEN 1 ELSE 0 END) AS null_order_item_id,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(Order_Id)),'')       IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(Customer_Id)),'')    IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(Product_Card_Id)),'') IS NULL THEN 1 ELSE 0 END) AS null_product_id,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(Order_Zipcode)),'')  IS NULL THEN 1 ELSE 0 END) AS null_order_zipcode,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(order_date_DateOrders)),'') IS NULL THEN 1 ELSE 0 END) AS null_order_date
FROM BRONZE.Orders;

-- Customers
SELECT
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(Customer_Id)),'')      IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(Customer_Lname)),'')   IS NULL THEN 1 ELSE 0 END) AS null_lname,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(Customer_Zipcode)),'') IS NULL THEN 1 ELSE 0 END) AS null_zipcode
FROM BRONZE.Customers;

-- Products
SELECT
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(Product_Card_Id)),'')     IS NULL THEN 1 ELSE 0 END) AS null_product_id,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(Product_Description)),'') IS NULL THEN 1 ELSE 0 END) AS null_description
FROM BRONZE.Products;


SELECT Order_Item_Id, COUNT(*) AS cnt
FROM BRONZE.Orders GROUP BY Order_Item_Id HAVING COUNT(*) > 1;

SELECT Customer_Id, COUNT(*) AS cnt
FROM BRONZE.Customers GROUP BY Customer_Id HAVING COUNT(*) > 1;

SELECT Product_Card_Id, COUNT(*) AS cnt
FROM BRONZE.Products GROUP BY Product_Card_Id HAVING COUNT(*) > 1;

SELECT COUNT(*) AS total_rows, COUNT(DISTINCT Order_Id) AS distinct_order_ids
FROM BRONZE.Orders;


SELECT COUNT(*) AS orphan_customers
FROM BRONZE.Orders o
LEFT JOIN BRONZE.Customers c ON c.Customer_Id = o.Customer_Id
WHERE c.Customer_Id IS NULL;

SELECT COUNT(*) AS orphan_products
FROM BRONZE.Orders o
LEFT JOIN BRONZE.Products p ON p.Product_Card_Id = o.Product_Card_Id
WHERE p.Product_Card_Id IS NULL;


-- Orders
SELECT
    SUM(CASE WHEN Order_Item_Id IS NOT NULL AND TRY_CAST(Order_Item_Id AS INT) IS NULL THEN 1 ELSE 0 END) AS bad_order_item_id,
    SUM(CASE WHEN Order_Id       IS NOT NULL AND TRY_CAST(Order_Id AS INT) IS NULL THEN 1 ELSE 0 END) AS bad_order_id,
    SUM(CASE WHEN Days_for_shipping_real      IS NOT NULL AND TRY_CAST(Days_for_shipping_real AS INT) IS NULL THEN 1 ELSE 0 END) AS bad_days_real,
    SUM(CASE WHEN Days_for_shipment_scheduled IS NOT NULL AND TRY_CAST(Days_for_shipment_scheduled AS INT) IS NULL THEN 1 ELSE 0 END) AS bad_days_sched,
    SUM(CASE WHEN Benefit_per_order    IS NOT NULL AND TRY_CAST(Benefit_per_order AS DECIMAL(18,4)) IS NULL THEN 1 ELSE 0 END) AS bad_benefit,
    SUM(CASE WHEN Order_Item_Discount  IS NOT NULL AND TRY_CAST(Order_Item_Discount AS DECIMAL(18,4)) IS NULL THEN 1 ELSE 0 END) AS bad_discount,
    SUM(CASE WHEN Order_Item_Profit_Ratio IS NOT NULL AND TRY_CAST(Order_Item_Profit_Ratio AS DECIMAL(18,4)) IS NULL THEN 1 ELSE 0 END) AS bad_profit_ratio,
    SUM(CASE WHEN Order_Item_Quantity  IS NOT NULL AND TRY_CAST(Order_Item_Quantity AS INT) IS NULL THEN 1 ELSE 0 END) AS bad_quantity,
    SUM(CASE WHEN Order_Item_Total     IS NOT NULL AND TRY_CAST(Order_Item_Total AS DECIMAL(18,4)) IS NULL THEN 1 ELSE 0 END) AS bad_total,
    SUM(CASE WHEN Late_delivery_risk   IS NOT NULL AND TRY_CAST(Late_delivery_risk AS INT) IS NULL THEN 1 ELSE 0 END) AS bad_late_risk,
    SUM(CASE WHEN order_date_DateOrders    IS NOT NULL AND TRY_CONVERT(DATETIME, order_date_DateOrders, 101) IS NULL THEN 1 ELSE 0 END) AS bad_order_date,
    SUM(CASE WHEN shipping_date_DateOrders IS NOT NULL AND TRY_CONVERT(DATETIME, shipping_date_DateOrders, 101) IS NULL THEN 1 ELSE 0 END) AS bad_ship_date
FROM BRONZE.Orders;

-- Products
SELECT
    SUM(CASE WHEN Product_Price IS NOT NULL AND TRY_CAST(Product_Price AS DECIMAL(18,4)) IS NULL THEN 1 ELSE 0 END) AS bad_price,
    SUM(CASE WHEN Product_Card_Id IS NOT NULL AND TRY_CAST(Product_Card_Id AS INT) IS NULL THEN 1 ELSE 0 END) AS bad_product_id
FROM BRONZE.Products;

-- Customers
SELECT
    SUM(CASE WHEN Customer_Id IS NOT NULL AND TRY_CAST(Customer_Id AS INT) IS NULL THEN 1 ELSE 0 END) AS bad_customer_id
FROM BRONZE.Customers;

/* F) Categorical checks*/
SELECT Delivery_Status, COUNT(*) AS cnt FROM BRONZE.Orders GROUP BY Delivery_Status ORDER BY cnt DESC;
SELECT Order_Status,    COUNT(*) AS cnt FROM BRONZE.Orders GROUP BY Order_Status    ORDER BY cnt DESC;
SELECT Shipping_Mode,   COUNT(*) AS cnt FROM BRONZE.Orders GROUP BY Shipping_Mode   ORDER BY cnt DESC;
SELECT Market,          COUNT(*) AS cnt FROM BRONZE.Orders GROUP BY Market          ORDER BY cnt DESC;
SELECT Type,            COUNT(*) AS cnt FROM BRONZE.Orders GROUP BY Type            ORDER BY cnt DESC;
SELECT Customer_Segment, COUNT(*) AS cnt FROM BRONZE.Customers GROUP BY Customer_Segment ORDER BY cnt DESC;
SELECT Category_Name,   COUNT(*) AS cnt FROM BRONZE.Products GROUP BY Category_Name ORDER BY cnt DESC;
SELECT Department_Name, COUNT(*) AS cnt FROM BRONZE.Products GROUP BY Department_Name ORDER BY cnt DESC;


SELECT COUNT(*) AS negative_shipping_days
FROM BRONZE.Orders
WHERE TRY_CAST(Days_for_shipping_real AS INT) < 0
   OR TRY_CAST(Days_for_shipment_scheduled AS INT) < 0;

SELECT COUNT(*) AS non_positive_quantity
FROM BRONZE.Orders
WHERE TRY_CAST(Order_Item_Quantity AS INT) <= 0;

SELECT COUNT(*) AS non_positive_price
FROM BRONZE.Products
WHERE TRY_CAST(Product_Price AS DECIMAL(18,4)) <= 0;