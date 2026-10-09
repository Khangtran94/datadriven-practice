# The Balance Always Reconciles

*Money out, payments back. The balance has to be exact.*

[Data Modeling · Easy · on DataDriven](https://datadriven.io/problems/the_balance_always_reconciles)

## How it went

| | |
|---|---|
| Solved | 2026-10-09 |
| Accepted | on the 3rd submission |
| Hints | none |
| Concepts | Attributes, Constraints, Entities, 1NF, Foreign Keys, Grain Definition, Immutable Logs, Key Generation, Metric Additivity, One-to-Many, Primary Keys, 2NF, Surrogate Keys, 3NF |

## The design

```mermaid
erDiagram
    dim_customer {
        INT customer_id PK
        CHAR name
        CHAR phone
        CHAR email
    }
    dim_date {
        INT date_sk PK
        INT day
        INT month
        INT year
    }
    fact_application {
        INT application_id PK
        INT customer_id FK
        INT date_sk FK
        CHAR loan_type
        BIGINT loan_amount
        DECIMAL interest_rate
        INT term_length
    }
    payment {
        INT payment_id PK
        INT application_id FK
        BIGINT amount_paid
        CHAR status
        DATE paid_date
    }
    dim_customer only one optionally to zero or more fact_application : "customer_id"
    dim_date only one optionally to zero or more fact_application : "date_sk"
    fact_application only one optionally to zero or more payment : "application_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
