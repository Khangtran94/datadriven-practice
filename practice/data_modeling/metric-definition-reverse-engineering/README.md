# Metric Definition Reverse Engineering

*Five numbers on a dashboard. Your job: figure out where they come from.*

[Data Modeling · Hard · on DataDriven](https://datadriven.io/problems/metric_definition_reverse_engineering)

## How it went

| | |
|---|---|
| Solved | 2026-10-29 |
| Accepted | on the first submission |
| Hints | none |
| Concepts | Attributes, Denormalization, Dimension Tables, Event Sourcing, Fact Tables, Foreign Keys, Grain Definition, Metric Additivity, One-to-Many, Pre-Aggregation, Primary Keys, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_user {
        INT user_id PK
        CHAR name
        CHAR phone
        CHAR email
        DATE signup_at
    }
    fact_order {
        INT order_id PK
        DATE order_date FK
        INT user_id FK
        TIMESTAMP order_time
        TIMESTAMP delivery_time
        DECIMAL amount
        BOOLEAN status_completed
    }
    dim_date {
        DATE date_sk PK
        INT month
        INT year
    }
    user_stat {
        INT user_stat_id PK
        DATE tracking_date FK
        INT user_id FK
        INT total_revenue
        INT total_order
        INT customer_lifetime_value
    }
    overall_stat {
        INT stat_id PK
        DATE date_sk FK
        INT DAU
        INT order_count
        INT complete_count
        DECIMAL order_completion_rate
        DECIMAL average_delivery_time
    }
    dim_user only one optionally to zero or more fact_order : "user_id"
    dim_date only one optionally to zero or more fact_order : "order_date = date_sk"
    dim_date only one optionally to zero or more overall_stat : "date_sk"
    dim_date only one optionally to zero or more user_stat : "tracking_date = date_sk"
    dim_user only one optionally to zero or more user_stat : "user_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
