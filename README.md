# Retail Supply Chain Data Warehouse & BI Reporting (DataCo)

End-to-end data project: raw CSVs → SQL Server data warehouse (Bronze/Silver/Gold)
→ star schema → 4-page Power BI report.

**Tools:** SQL Server (T-SQL), Power BI, DAX
**Data:** DataCo Smart Supply Chain dataset (public, Kaggle), about 180K order items,
20K customers, 118 products.

## Architecture
Bronze (raw import) → Silver (cleaned, typed, derived columns) → Gold (star schema) → Power BI

![DWH diagram](docs/DWH.png)

## Data Cleaning Highlights
- Standardized inconsistent categories: `market` (13 spellings → 5 markets),
  `shipping_mode` (9 → 4), `delivery_status` (8 → 4)
- Removed PII (email, password, birth date) and an empty column (`Product_Description`)
- Excluded `Order_Zipcode` from the Gold layer (about 86% blank)
- Derived columns: `shipping_delay_days`, `is_late_delivery`, `price_tier` (terciles), `customer_full_name`
- Validated nulls, duplicates, orphan keys, type casts, and ranges before building Silver

## Data Model (Gold)
Grain: one row per order item. `FactOrders` with `DimDate` (role-playing: order and ship date),
`DimCustomer`, `DimProduct`, `DimShipping`, `DimMarket`. PK/FK constraints and indexes included.

## Dashboards

### Sales & Profitability
![Sales](powerbi/screenshots/1-sales-profitability.png)

### Delivery & Logistics
![Delivery](powerbi/screenshots/2-delivery-logistics.png)

### Customer Segmentation
![Customers](powerbi/screenshots/3-customer-segmentation.png)

### Product & Category
![Products](powerbi/screenshots/4-product-category.png)

## Key Insights
- Europe and LATAM generate about 57% of revenue and profit. Margins are similar across
  markets, so profit differences come from volume, not efficiency.
- About 57% of order items (excluding canceled) are delivered late, consistently across
  all markets, but it varies by shipping mode: First Class is late on 95.3% of items vs 38% for Standard.
- Puerto Rico alone accounts for 38.4% of revenue by customer location.
- Fishing is the top category (about 19% of revenue) with only 17K units sold; its lead
