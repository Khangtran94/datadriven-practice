# One Door Each

*Every user picks a lane and stays in it. Model the world so the numbers stay honest.*

[Data Modeling · Medium · on DataDriven](https://datadriven.io/problems/one_door_each)

## How it went

| | |
|---|---|
| Solved | 2026-10-19 |
| Accepted | on the 4th submission |
| Hints | none |
| Concepts | Attributes, Cardinality, Composite Keys, Constraints, Dimension Tables, Entities, Fact Tables, Foreign Keys, Grain Definition, Immutable Logs, Junction Tables, Many-to-Many, Metric Additivity, One-to-Many, Primary Keys, Semantic Layer, Star Schema, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_user {
        INT user_id PK
        CHAR name
        CHAR phone
        CHAR email
    }
    dim_experiment {
        INT experiment_id PK
        CHAR name
    }
    assignment {
        INT experiment_id PK
        INT user_id PK
        CHAR variant
        TIMESTAMP enrolled_at
        BOOLEAN is_control
    }
    event_log {
        INT event_id PK
        INT user_id FK
        CHAR event_type
        TIMESTAMP event_time
    }
    dim_experiment only one to zero or more assignment : "experiment_id"
    dim_user only one to zero or more assignment : "user_id"
    dim_user only one optionally to zero or more event_log : "user_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
