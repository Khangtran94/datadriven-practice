# Every Line Counts

*Every beep at the register. Coupons, returns, all of it.*

[Data Modeling · Medium · on DataDriven](https://datadriven.io/problems/every_line_counts)

## How it went

| | |
|---|---|
| Solved | 2026-10-12 |
| Accepted | on the first submission |
| Hints | none |
| Concepts | Dimension Tables, Fact Tables, Foreign Keys, Junction Tables, Many-to-Many, One-to-Many, Primary Keys, Star Schema, Surrogate Keys |

## The design

```mermaid
erDiagram
    fact_receipt_line {
        INT receipt_id PK
        INT date_scanned FK
        INT store_id FK
        INT promotion_product_sk FK
        DECIMAL total_amount
    }
    dim_store {
        INT store_id PK
        INT region_id FK
        CHAR name
        CHAR city
        CHAR address
    }
    dim_date {
        INT date_sk PK
        DATE full_date
        INT month
        INT year
    }
    dim_region {
        INT region_id PK
        CHAR name
    }
    dim_product {
        INT product_id PK
        CHAR name
        INT department_name
    }
    dim_promotion {
        INT promotion_id PK
        CHAR name
        CHAR type
        CHAR campaign_name
    }
    bridge_promotion_product {
        INT promotion_product_sk PK
        INT promotion_id FK
        INT product_id FK
        DECIMAL discount_rate
    }
    dim_region only one optionally to zero or more dim_store : "region_id"
    dim_date only one optionally to zero or more fact_receipt_line : "date_scanned = date_sk"
    dim_product only one optionally to zero or more bridge_promotion_product : "product_id"
    dim_promotion only one optionally to zero or more bridge_promotion_product : "promotion_id"
    dim_store only one optionally to zero or more fact_receipt_line : "store_id"
    bridge_promotion_product only one optionally to zero or more fact_receipt_line : "promotion_product_sk"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
