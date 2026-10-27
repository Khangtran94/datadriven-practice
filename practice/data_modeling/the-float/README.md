# The Float

[Data Modeling · Medium · on DataDriven](https://datadriven.io/problems/the_float)

## How it went

| | |
|---|---|
| Solved | 2026-10-27 |
| Accepted | on the 5th submission |
| Hints | 3 hints |
| Concepts | Attributes, Constraints, Data Types, Dimension Tables, Entities, Fact Tables, Foreign Keys, Grain Definition, Many-to-Many, Metric Additivity, One-to-Many, Pre-Aggregation, Primary Keys, Star Schema, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_date {
        DATE date_sk PK
        INT month
        INT year
    }
    dim_customer {
        INT customer_id PK
        DATE signup_at FK
        CHAR name
        CHAR phone
        CHAR email
    }
    dim_account {
        INT account_id PK
        DATE date_registered FK
        DATE due_date FK
        INT customer_id FK
        CHAR card_number
        DECIMAL initial_amount
    }
    fact_hold {
        INT hold_id PK
        DATE event_date FK
        INT account_id FK
        TIMESTAMP host_time
        DECIMAL hold_amount
        CHAR status
    }
    tracking_dispute {
        INT track_id PK
        DATE dispute_date FK
        INT charged_id FK
        CHAR dispute_type
    }
    fact_charged {
        INT charged_id PK
        INT hold_id FK
        DATE charged_date FK
        TIMESTAMP charged_time
        DECIMAL charged_amount
    }
    dim_date only one optionally to zero or more dim_customer : "signup_at = date_sk"
    dim_customer only one optionally to zero or more dim_account : "customer_id"
    dim_date only one optionally to zero or more dim_account : "due_date = date_sk"
    dim_date only one optionally to zero or more dim_account : "date_registered = date_sk"
    dim_date only one optionally to zero or more fact_hold : "event_date = date_sk"
    dim_date only one optionally to zero or more tracking_dispute : "dispute_date = date_sk"
    dim_account only one optionally to zero or more fact_hold : "account_id"
    fact_hold only one optionally to zero or more fact_charged : "hold_id"
    fact_charged only one optionally to zero or more tracking_dispute : "charged_id"
    dim_date only one optionally to zero or more fact_charged : "charged_date = date_sk"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
