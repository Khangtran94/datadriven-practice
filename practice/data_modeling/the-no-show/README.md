# The No-Show

*Every reserved seat ends one of five ways. Build the model that can tell them apart.*

[Data Modeling · Easy · on DataDriven](https://datadriven.io/problems/the_no_show)

## How it went

| | |
|---|---|
| Solved | 2026-10-12 |
| Accepted | on the first submission |
| Hints | none |
| Concepts | Attributes, Constraints, Data Types, Dimension Tables, Entities, Fact Tables, 1NF, Foreign Keys, Grain Definition, Junction Tables, Many-to-Many, One-to-Many, Primary Keys, 2NF, Star Schema, Surrogate Keys, 3NF |

## The design

```mermaid
erDiagram
    dim_date {
        INT date_sk PK
        DATE full_date
        INT month
        INT year
    }
    dim_member {
        INT member_id PK
        DATE name
        INT phone
        INT email
    }
    dim_tier {
        INT tier_id PK
        CHAR name
        DECIMAL monthly_fee
        INT number_of_class
    }
    member_tier {
        INT member_tier_sk PK
        INT member_id PK
        INT tier_id PK
        DATE from_date
        DATE to_date
        BOOLEAN is_current
    }
    session {
        INT session_id PK
        INT studio_id FK
        DATE date_started FK
    }
    dim_studio {
        INT studio_id PK
        CHAR name
    }
    booking {
        INT booking_id PK
        INT session_id FK
        INT member_tier_sk FK
        CHAR booking_status
        TIMESTAMP checkin_time
    }
    dim_member only one to zero or more member_tier : "member_id"
    dim_tier only one to zero or more member_tier : "tier_id"
    dim_studio only one optionally to zero or more session : "studio_id"
    dim_date only one optionally to zero or more session : "date_started = date_sk"
    session only one optionally to zero or more booking : "session_id"
    member_tier only one optionally to zero or more booking : "member_tier_sk"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
