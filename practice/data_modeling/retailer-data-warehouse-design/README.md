# Retailer Data Warehouse Design

*Queries are crawling. The analysts are not happy.*

[Data Modeling · Medium · on DataDriven](https://datadriven.io/problems/retailer_data_warehouse_design)

## How it went

| | |
|---|---|
| Solved | 2026-11-10 |
| Accepted | on the first submission |
| Hints | none |
| Concepts | Attributes, Denormalization, Dimension Tables, Fact Tables, Foreign Keys, Grain Definition, Metric Additivity, One-to-Many, Primary Keys, Star Schema, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_date {
        INT date_sk PK
        DATE full_date
        INT month
        INT year
    }
    dim_customer {
        INT customer_id PK
        CHAR name
        CHAR phone
        CHAR email
        CHAR tier
    }
    dim_product {
        INT product_id PK
        CHAR name
        DECIMAL price
        CHAR type
    }
    fact_order {
        INT order_id PK
        INT order_date FK
        INT customer_id FK
        INT product_id FK
        INT quantity
        DECIMAL total_amount
    }
    dim_date only one optionally to zero or more fact_order : "order_date = date_sk"
    dim_customer only one optionally to zero or more fact_order : "customer_id"
    dim_product only one optionally to zero or more fact_order : "product_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
