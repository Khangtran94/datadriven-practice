# Marketplace Sales Warehouse

*No schema given. The interviewer is watching.*

[Data Modeling · Hard · on DataDriven](https://datadriven.io/problems/marketplace_sales_warehouse)

## How it went

| | |
|---|---|
| Solved | 2026-10-16 |
| Accepted | on the 3rd submission |
| Hints | none |
| Concepts | Denormalization, Dimension Tables, Fact Tables, Foreign Keys, Grain Definition, Metric Additivity, One-to-Many, Primary Keys, Snowflake Schema, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_date {
        INT date_sk PK
        DATE full_date
        INT month
        INT year
    }
    dim_account {
        INT account_sk PK
        INT account_id
        CHAR name
        CHAR phone
        CHAR email
        CHAR region
        DATE effective_from
        DATE effective_to
        BOOLEAN is_current
    }
    dim_product {
        INT product_id PK
        INT category_id FK
        CHAR name
    }
    dim_category {
        INT category_id PK
        CHAR name
        INT parent_category_id
    }
    fact_order_line {
        INT order_line_id PK
        INT order_id FK
        INT product_id FK
        INT seller_id FK
        INT quantity
        DECIMAL unit_price
        INT order_date
        DECIMAL commission_rate
    }
    order_table {
        INT order_id PK
        INT order_date FK
        INT buyer_id FK
        DECIMAL estimated_amount
    }
    dim_category only one optionally to zero or more dim_product : "category_id"
    dim_date only one optionally to zero or more order_table : "order_date = date_sk"
    order_table only one optionally to zero or more fact_order_line : "order_id"
    dim_product only one optionally to zero or more fact_order_line : "product_id"
    dim_account only one optionally to zero or more order_table : "buyer_id = account_sk"
    dim_account only one optionally to zero or more fact_order_line : "seller_id = account_sk"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
