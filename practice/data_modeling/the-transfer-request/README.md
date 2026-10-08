# The Transfer Request

*Apply, wait, get approved or denied. Track all of it.*

[Data Modeling · Medium · on DataDriven](https://datadriven.io/problems/the_transfer_request)

## How it went

| | |
|---|---|
| Solved | 2026-10-08 |
| Accepted | on the first submission |
| Hints | none |
| Concepts | Attributes, Cardinality, Constraints, Data Types, Dimension Tables, Entities, Fact Tables, 1NF, Foreign Keys, Grain Definition, Metric Additivity, One-to-Many, Primary Keys, 2NF, Star Schema, Surrogate Keys, 3NF |

## The design

```mermaid
erDiagram
    dim_date {
        INT date_sk PK
        INT day
        INT month
        INT year
    }
    dim_employee {
        INT employee_id PK
        CHAR name
        CHAR phone
        CHAR email
    }
    fact_application {
        INT application_id PK
        INT date_sk FK
        INT employee_id FK
        CHAR originating_team
        CHAR destination_team
        CHAR status
    }
    dim_date only one optionally to zero or more fact_application : "date_sk"
    dim_employee only one optionally to zero or more fact_application : "employee_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
