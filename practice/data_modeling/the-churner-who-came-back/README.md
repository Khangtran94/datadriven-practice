# The Churner Who Came Back

*They cancelled. They came back. The report has to tell both stories correctly.*

[Data Modeling · Hard · on DataDriven](https://datadriven.io/problems/the_churner_who_came_back)

## How it went

| | |
|---|---|
| Solved | 2026-11-26 |
| Accepted | on the 2nd submission |
| Hints | none |
| Concepts | Attributes, Dimension Tables, Entities, Fact Tables, Foreign Keys, Grain Definition, Key Generation, Many-to-Many, Metric Additivity, OLAP Cubes, One-to-Many, Primary Keys, SCD Type 2, Star Schema, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_date {
        INT date_sk PK
        DATE full_date
        INT month
        INT year
    }
    dim_subscriber {
        INT subscriber_id PK
        CHAR name
        CHAR phone
        CHAR email
        CHAR region
    }
    dim_plan_tier {
        INT plan_tier_id PK
        CHAR plan_tier_name
    }
    subscriber_key {
        INT subscriber_sk PK
        INT date_applied FK
        INT subscriber_id FK
        INT plan_tier_id FK
        CHAR status
        BOOLEAN is_active
    }
    fact_monthly_invoice {
        INT invoice_id PK
        INT invoice_date FK
        INT subscriber_sk FK
        INT month
        DECIMAL revenue
    }
    dim_date only one optionally to zero or more subscriber_key : "date_applied = date_sk"
    dim_plan_tier only one optionally to zero or more subscriber_key : "plan_tier_id"
    dim_subscriber only one optionally to zero or more subscriber_key : "subscriber_id"
    subscriber_key only one optionally to zero or more fact_monthly_invoice : "subscriber_sk"
    dim_date only one optionally to zero or more fact_monthly_invoice : "invoice_date = date_sk"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
