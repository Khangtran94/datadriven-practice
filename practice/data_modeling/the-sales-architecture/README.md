# The Sales Architecture

*Numbers are easy. Making them queryable at scale is the real job.*

[Data Modeling · Medium · on DataDriven](https://datadriven.io/problems/the_sales_architecture)

## How it went

| | |
|---|---|
| Solved | 2026-10-27 |
| Accepted | on the first submission |
| Hints | none |
| Concepts | Denormalization, Dimension Tables, Fact Tables, Foreign Keys, Grain Definition, Metric Additivity, One-to-Many, Primary Keys, Star Schema, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_date {
        DATE date_sk PK
        TEXT month
        INT year
    }
    dim_product {
        INT product_id PK
        CHAR name
        CHAR genre
        DECIMAL price
    }
    dim_seller {
        INT seller_id PK
        INT region_id FK
        CHAR name
        CHAR phone
        CHAR email
        DATE signup_at
    }
    dim_customer {
        INT customer_id PK
        INT region_id FK
        CHAR name
        CHAR phone
        CHAR email
        DATE signup_at
    }
    dim_region {
        INT region_id PK
        CHAR name
    }
    fact_transaction {
        INT event_id PK
        DATE event_date FK
        TIMESTAMP event_time
        INT product_id FK
        CHAR event_type
        INT seller_id FK
        INT customer_id FK
        INT quantity
        DECIMAL amount
    }
    dim_region only one optionally to zero or more dim_seller : "region_id"
    dim_region only one optionally to zero or more dim_customer : "region_id"
    dim_date only one optionally to zero or more fact_transaction : "event_date = date_sk"
    dim_product only one optionally to zero or more fact_transaction : "product_id"
    dim_seller only one optionally to zero or more fact_transaction : "seller_id"
    dim_customer only one optionally to zero or more fact_transaction : "customer_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
