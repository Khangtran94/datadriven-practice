# The Person They Were Then

[Data Modeling · Easy · on DataDriven](https://datadriven.io/problems/the_person_they_were_then)

## How it went

| | |
|---|---|
| Solved | 2026-10-27 |
| Accepted | on the first submission |
| Hints | none |
| Concepts | Denormalization, Dimension Tables, Fact Tables, Foreign Keys, Grain Definition, Metric Additivity, One-to-Many, Primary Keys, SCD Strategy, SCD Type 2, Star Schema, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_user {
        INT user_sk PK
        INT user_id
        CHAR name
        CHAR subscription_tier
        CHAR country
        DATE from_date FK
        DATE to_date FK
        BOOLEAN is_active
    }
    dim_date {
        DATE full_date PK
        INT month
        INT year
    }
    fact_event {
        INT event_id PK
        DATE event_date FK
        INT user_sk FK
        DECIMAL revenue
    }
    dim_date only one optionally to zero or more dim_user : "from_date = full_date"
    dim_date only one optionally to zero or more dim_user : "to_date = full_date"
    dim_date only one optionally to zero or more fact_event : "event_date = full_date"
    dim_user only one optionally to zero or more fact_event : "user_sk"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
