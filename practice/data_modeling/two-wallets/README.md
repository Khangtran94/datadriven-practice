# Two Wallets

*Two user types. Multiple payment methods. One messy billing table.*

[Data Modeling · Medium · on DataDriven](https://datadriven.io/problems/two_wallets)

## How it went

| | |
|---|---|
| Solved | 2026-10-09 |
| Accepted | on the 2nd submission |
| Hints | none |
| Concepts | Constraints, Data Types, Dimension Tables, Entities, Fact Tables, 1NF, Foreign Keys, Grain Definition, Immutable Logs, Key Generation, One-to-Many, Primary Keys, 2NF, Star Schema, Surrogate Keys, 3NF |

## The design

```mermaid
erDiagram
    dim_user {
        INT user_id PK
        CHAR name
        CHAR phone
        CHAR email
        CHAR user_type
    }
    payment {
        INT payment_id PK
        CHAR user_id FK
        CHAR token
        CHAR payment_method
        CHAR last_four_digits
        CHAR plan_tier
        DATE subscribed_started
        DATE subscribed_ended
    }
    dim_user only one optionally to zero or more payment : "user_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
