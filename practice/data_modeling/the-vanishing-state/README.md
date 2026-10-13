# The Vanishing State

*A status column forgets the moment it changes. Model the schema that remembers.*

[Data Modeling · Easy · on DataDriven](https://datadriven.io/problems/the_vanishing_state)

## How it went

| | |
|---|---|
| Solved | 2026-10-13 |
| Accepted | on the 4th submission |
| Hints | none |
| Concepts | Attributes, Cardinality, Constraints, Data Types, Entities, Event Sourcing, 1NF, Foreign Keys, Grain Definition, Immutable Logs, Metric Additivity, One-to-Many, Primary Keys, 2NF, Surrogate Keys, 3NF |

## The design

```mermaid
erDiagram
    dim_user {
        INT user_id PK
        CHAR name
    }
    ticket_lifecycle {
        INT ticket_id PK
        INT agent_id FK
        INT user_id FK
        INT ticket_type_id FK
        INT date_created FK
        TIMESTAMP created_time
        TIMESTAMP opened_time
        TIMESTAMP processed_time
        TIMESTAMP resolved_time
        CHAR current_status
    }
    dim_ticket_type {
        INT ticket_type_id PK
        CHAR name
        INT time_to_solve
    }
    dim_date {
        INT date_sk PK
        DATE full_date
        INT month
        INT year
    }
    dim_agent {
        INT agent_id PK
        CHAR name
        CHAR description
    }
    status_log {
        INT log_id PK
        INT ticket_id FK
        CHAR status
        TIMESTAMP changed_at
    }
    dim_date only one optionally to zero or more ticket_lifecycle : "date_created = date_sk"
    dim_ticket_type only one optionally to zero or more ticket_lifecycle : "ticket_type_id"
    dim_user only one optionally to zero or more ticket_lifecycle : "user_id"
    dim_agent only one optionally to zero or more ticket_lifecycle : "agent_id"
    ticket_lifecycle only one optionally to zero or more status_log : "ticket_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
