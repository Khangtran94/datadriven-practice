# The Rate That Was

[Data Modeling · Medium · on DataDriven](https://datadriven.io/problems/the_rate_that_was)

## How it went

| | |
|---|---|
| Solved | 2026-10-20 |
| Accepted | on the first submission |
| Hints | none |
| Concepts | Attributes, Constraints, Data Types, Dimension Tables, Entities, Fact Tables, Foreign Keys, Grain Definition, Junction Tables, Many-to-Many, One-to-Many, Primary Keys, SCD Strategy, SCD Type 2, Star Schema, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_consultant {
        INT consultant_id PK
        CHAR name
        CHAR phone
        CHAR email
    }
    dim_client {
        INT client_id PK
        CHAR name
        CHAR address
        CHAR phone
    }
    fact_rate {
        INT rate_id PK
        INT consultant_id FK
        INT client_id FK
        DECIMAL rate_per_hour
        INT from_date FK
        INT to_date FK
        BOOLEAN is_active
    }
    dim_date {
        INT date_sk PK
        DATE full_date
        INT month
        INT year
    }
    log_billable {
        INT bill_id PK
        INT rate_id FK
        INT bill_date FK
        DECIMAL log_hour
    }
    fact_invoice {
        INT invoice_id PK
        INT bill_id FK
        INT invoice_date FK
        DECIMAL total_amount
        CHAR status
    }
    dim_client only one optionally to zero or more fact_rate : "client_id"
    dim_consultant only one optionally to zero or more fact_rate : "consultant_id"
    dim_date only one optionally to zero or more fact_rate : "from_date = date_sk"
    dim_date only one optionally to zero or more fact_rate : "to_date = date_sk"
    fact_rate only one optionally to zero or more log_billable : "rate_id"
    dim_date only one optionally to zero or more log_billable : "bill_date = date_sk"
    log_billable only one optionally to zero or more fact_invoice : "bill_id"
    dim_date only one optionally to zero or more fact_invoice : "invoice_date = date_sk"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
