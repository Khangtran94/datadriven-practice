# Personal Best

*Reps, sets, streaks, and personal bests. Gym rats love their stats.*

[Data Modeling · Easy · on DataDriven](https://datadriven.io/problems/personal_best)

## How it went

| | |
|---|---|
| Solved | 2026-10-08 |
| Accepted | on the 2nd submission |
| Hints | none |
| Concepts | Attributes, Data Types, Entities, 1NF, Foreign Keys, Grain Definition, One-to-Many, Primary Keys, 2NF, 3NF |

## The design

```mermaid
erDiagram
    dim_user {
        INT user_id PK
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
    dim_exercise {
        INT exercise_id PK
        CHAR name
    }
    fact_log {
        INT log_id PK
        INT user_id FK
        INT date_sk FK
        INT exercise_id FK
        INT sets
        INT reps
        INT weight_lifted
    }
    dim_user only one optionally to zero or more fact_log : "user_id"
    dim_date only one optionally to zero or more fact_log : "date_sk"
    dim_exercise only one optionally to zero or more fact_log : "exercise_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
