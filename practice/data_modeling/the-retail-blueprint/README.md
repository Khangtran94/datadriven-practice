# The Retail Blueprint

*One business. A thousand transactions. Only one layout survives the analytics layer.*

[Data Modeling · Medium · on DataDriven](https://datadriven.io/problems/the_retail_blueprint)

## How it went

| | |
|---|---|
| Solved | 2026-11-10 |
| Accepted | on the first submission |
| Hints | none |
| Concepts | Denormalization, Dimension Tables, Fact Tables, Foreign Keys, Grain Definition, Metric Additivity, One-to-Many, Primary Keys, Star Schema, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_date {
        INT date_sk PK
        DATE full_date
        INT month
        INT year
    }
    dim_product {
        INT product_id PK
        CHAR name
        CHAR category
        DECIMAL price
    }
    dim_channel {
        INT channel_id PK
        CHAR channel_type
        CHAR channel_name
    }
    dim_customer {
        INT customer_id PK
        CHAR name
        CHAR phone
        CHAR email
        CHAR membership_tier
        CHAR city
        CHAR country
    }
    fact_order {
        INT order_id PK
        INT order_date FK
        INT channel_id FK
        INT customer_id FK
        INT product_id FK
        INT quantity
        DECIMAL total_amount
    }
    dim_product only one optionally to zero or more fact_order : "product_id"
    dim_channel only one optionally to zero or more fact_order : "channel_id"
    dim_customer only one optionally to zero or more fact_order : "customer_id"
    dim_date only one optionally to zero or more fact_order : "order_date = date_sk"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
