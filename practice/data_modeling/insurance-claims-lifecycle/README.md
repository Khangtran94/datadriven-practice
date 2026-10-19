# Insurance Claims Lifecycle

*A claim gets filed. Then it gets complicated. Then it gets reassigned. Then it loops back.*

[Data Modeling · Hard · on DataDriven](https://datadriven.io/problems/insurance_claims_lifecycle)

## How it went

| | |
|---|---|
| Solved | 2026-10-19 |
| Accepted | on the 2nd submission |
| Hints | none |
| Concepts | Attributes, Data Types, Dimension Tables, Entities, Fact Tables, Foreign Keys, Grain Definition, One-to-Many, Primary Keys, SCD Type 2, Star Schema, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_date {
        INT date_sk PK
        DATE full_date
        INT month
        INT year
    }
    claim_lifecycle {
        INT claim_id PK
        INT customer_sk FK
        INT filed_date FK
        DECIMAL amount
        CHAR status
    }
    dim_customer {
        INT customer_sk PK
        INT customer_id
        CHAR name
        CHAR phone
        CHAR email
        CHAR address
        CHAR city
        DATE effective_from
        DATE effective_to
        BOOLEAN is_current
    }
    version_log {
        INT log_id PK
        INT claim_id FK
        INT date_updated FK
        CHAR updated_status
    }
    dim_customer only one optionally to zero or more claim_lifecycle : "customer_sk"
    dim_date only one optionally to zero or more claim_lifecycle : "filed_date = date_sk"
    claim_lifecycle only one optionally to zero or more version_log : "claim_id"
    dim_date only one optionally to zero or more version_log : "date_updated = date_sk"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
