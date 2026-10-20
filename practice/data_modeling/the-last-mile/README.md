# The Last Mile

*Order placed. Now track it to the door.*

[Data Modeling · Medium · on DataDriven](https://datadriven.io/problems/the_last_mile)

## How it went

| | |
|---|---|
| Solved | 2026-10-20 |
| Accepted | on the first submission |
| Hints | none |
| Concepts | Attributes, Data Types, Dimension Tables, Entities, Fact Tables, Foreign Keys, Grain Definition, One-to-Many, Primary Keys, Snowflake Schema |

## The design

```mermaid
erDiagram
    dim_date {
        INT date_sk PK
        DATE full_date
        INT month
        INT year
    }
    dim_order {
        INT order_id PK
        DATE order_date FK
        unspecified customer_id FK
        DECIMAL total_amount
    }
    dim_date_copy {
        INT customer_id PK
        CHAR name
        CHAR phone
        CHAR email
    }
    dim_item {
        INT item_id PK
        CHAR name
        DECIMAL price
    }
    order_line_item {
        INT order_item_id PK
        INT item_id FK
        INT order_id FK
        unspecified quantity
    }
    package {
        INT package_id PK
        INT warehouse_id FK
        INT order_item_id FK
        CHAR current_status
    }
    dim_warehouse {
        INT warehouse_id PK
        CHAR name
        CHAR address
        CHAR city
    }
    package_event {
        INT event_id PK
        INT package_id FK
        CHAR event_type
        TIMESTAMP event_time
    }
    dim_date only one optionally to zero or more dim_order : "order_date = date_sk"
    dim_date_copy only one optionally to zero or more dim_order : "customer_id"
    dim_item only one optionally to zero or more order_line_item : "item_id"
    dim_order only one optionally to zero or more order_line_item : "order_id"
    dim_warehouse only one optionally to zero or more package : "warehouse_id"
    order_line_item only one optionally to zero or more package : "order_item_id"
    package only one optionally to zero or more package_event : "package_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
