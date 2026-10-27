# The Customer Who Changed

*She moved. She upgraded. She became someone new. The record has to keep up.*

[Data Modeling · Hard · on DataDriven](https://datadriven.io/problems/the_customer_who_changed)

## How it went

| | |
|---|---|
| Solved | 2026-05-25 |
| Accepted | on the 5th submission |
| Hints | none |
| Concepts | Dimension Tables, Fact Tables, Foreign Keys, Indexing, Primary Keys, SCD Strategy, SCD Type 2, Surrogate Keys |

## The design

```mermaid
erDiagram
    customer {
        INT customer_sk PK
        INT customer_id
        CHAR name
        CHAR address
        CHAR membership_tier
        CHAR email
        INT from_date FK
        INT to_date FK
        BOOLEAN is_active
    }
    fact_order {
        INT order_id PK
        INT order_date FK
        INT customer_sk FK
        INT quantity
        DECIMAL amount
    }
    dim_date {
        INT date_sk PK
        DATE full_date
        INT month
        INT year
    }
    dim_date only one optionally to zero or more fact_order : "order_date = date_sk"
    customer only one optionally to zero or more fact_order : "customer_sk"
    dim_date only one optionally to zero or more customer : "from_date = date_sk"
    dim_date only one optionally to zero or more customer : "to_date = date_sk"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
