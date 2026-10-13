# Open Threads

*Every minute tracked. Every app accounted for.*

[Data Modeling · Medium · on DataDriven](https://datadriven.io/problems/open_threads)

## How it went

| | |
|---|---|
| Solved | 2026-10-13 |
| Accepted | on the first submission |
| Hints | none |
| Concepts | Cardinality, Data Types, Dimension Tables, Entities, Event Sourcing, Fact Tables, Foreign Keys, Grain Definition, Immutable Logs, Late-Arriving Data, Many-to-Many, One-to-Many, Pre-Aggregation, Primary Keys, Star Schema, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_employee {
        INT employee_id PK
        VARCHAR name
    }
    dim_application {
        INT application_id PK
        VARCHAR name
    }
    daily_app_sessions {
        INT date_sk PK
        INT employee_id PK
        INT application_id PK
        INT duration
        TIMESTAMP start_ts
        TIMESTAMP end_ts
        BOOLEAN session_incomplete
        BOOLEAN flag_overdue
    }
    dim_date {
        INT date_sk PK
        DATE full_date
        INT month
        INT year
    }
    dim_employee only one to zero or more daily_app_sessions : "employee_id"
    dim_date only one to zero or more daily_app_sessions : "date_sk"
    dim_application only one to zero or more daily_app_sessions : "application_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
