# The Table That Lies

*Every query comes out wrong. The data is all there.*

[Data Modeling · Medium · on DataDriven](https://datadriven.io/problems/the_table_that_lies)

## How it went

| | |
|---|---|
| Solved | 2026-10-12 |
| Accepted | on the 2nd submission |
| Hints | none |
| Concepts | Attributes, Cardinality, Denormalization, Dimension Tables, Entities, Fact Tables, 1NF, Foreign Keys, Grain Definition, Junction Tables, Many-to-Many, Metric Additivity, One-to-Many, Primary Keys, 2NF, Star Schema, Surrogate Keys, 3NF |

## The design

```mermaid
erDiagram
    dim_stylist {
        INT stylist_id PK
        CHAR name
        CHAR phone
        CHAR email
    }
    dim_client {
        INT client_id PK
        CHAR name
        CHAR phone
        CHAR email
    }
    session_log {
        INT session_id PK
        INT session_date FK
        INT stylist_id FK
        INT client_id FK
        CHAR status
        TIMESTAMP start_time
        TIMESTAMP end_time
    }
    dim_date {
        INT date_sk PK
        DATE full_date
        INT month
        INT year
    }
    dim_item {
        INT item_id PK
        CHAR item_name
    }
    session_item {
        INT session_item_sk PK
        INT session_id FK
        INT item_id FK
        INT quantity
        DECIMAL unit_price
    }
    dim_stylist only one optionally to zero or more session_log : "stylist_id"
    dim_client only one optionally to zero or more session_log : "client_id"
    dim_date only one optionally to zero or more session_log : "session_date = date_sk"
    dim_item only one optionally to zero or more session_item : "item_id"
    session_log only one optionally to zero or more session_item : "session_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
