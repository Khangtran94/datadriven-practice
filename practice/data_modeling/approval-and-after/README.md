# Approval and After

*Approved, declined, or pending. Design the tables that say so.*

[Data Modeling · Medium · on DataDriven](https://datadriven.io/problems/approval_and_after)

## How it went

| | |
|---|---|
| Solved | 2026-10-08 |
| Accepted | on the 2nd submission |
| Hints | none |
| Concepts | Constraints, Data Types, Denormalization, Entities, 1NF, Foreign Keys, One-to-Many, One-to-One, Primary Keys, 2NF, Surrogate Keys, 3NF |

## The design

```mermaid
erDiagram
    dim_customer {
        INT customer_id PK
        CHAR name
        CHAR phone
        CHAR email
    }
    fact_application {
        INT application_id PK
        INT customer_sk FK
        DECIMAL loan_amount
        DATE date_applied
        CHAR status
    }
    dim_segment {
        INT segment_id PK
        INT credit_score
        CHAR segment_name
    }
    customer_segment {
        INT customer_sk PK
        INT customer_id FK
        INT segment_id FK
        DATE from_date
        DATE to_date
        BOOLEAN is_active
    }
    offer_application {
        INT offer_id PK
        INT application_id FK
        DATE date_offer
        DECIMAL offer_amount
        CHAR status
    }
    loan_offer {
        INT loan_id PK
        INT offer_id FK
        DATE date_loan
        DECIMAL loan_approved
    }
    dim_customer only one optionally to zero or more customer_segment : "customer_id"
    dim_segment only one optionally to zero or more customer_segment : "segment_id"
    customer_segment only one optionally to zero or more fact_application : "customer_sk"
    fact_application only one optionally to zero or more offer_application : "application_id"
    offer_application only one optionally to zero or more loan_offer : "offer_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
