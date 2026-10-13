# The Long Route

*A package splits, reroutes, and (maybe) arrives.*

[Data Modeling · Hard · on DataDriven](https://datadriven.io/problems/the_long_route)

## How it went

| | |
|---|---|
| Solved | 2026-10-13 |
| Accepted | on the first submission |
| Hints | none |
| Concepts | Attributes, Cardinality, Composite Keys, Constraints, Entities, Event Sourcing, 1NF, Foreign Keys, Grain Definition, Immutable Logs, Junction Tables, Late-Arriving Data, Many-to-Many, One-to-Many, Primary Keys, 2NF, Surrogate Keys, 3NF |

## The design

```mermaid
erDiagram
    order_item {
        INT order_item_id PK
        INT item_id FK
        INT order_id FK
        INT quantity
        INT amount
    }
    dim_order {
        INT order_id PK
        DATE order_date FK
        INT customer_id FK
    }
    dim_customer {
        INT customer_id PK
        CHAR name
        CHAR phone
        CHAR email
    }
    dim_date {
        INT date_sk PK
        DATE full_date
        INT month
        INT year
    }
    dim_item {
        INT item_id PK
        CHAR name
    }
    fact_shipment_cycle {
        INT shipment_id PK
        DATE picking_date FK
        DATE packing_date FK
        DATE loading_date FK
        CHAR current_status
        INT center_id FK
        INT order_item_id FK
    }
    dim_center {
        INT center_id PK
        CHAR name
        CHAR address
    }
    dim_customer only one optionally to zero or more dim_order : "customer_id"
    dim_date only one optionally to zero or more dim_order : "order_date = date_sk"
    dim_item only one optionally to zero or more order_item : "item_id"
    dim_order only one optionally to zero or more order_item : "order_id"
    dim_center only one optionally to zero or more fact_shipment_cycle : "center_id"
    order_item only one optionally to zero or more fact_shipment_cycle : "order_item_id"
    dim_date only one optionally to zero or more fact_shipment_cycle : "picking_date = date_sk"
    dim_date only one optionally to zero or more fact_shipment_cycle : "packing_date = date_sk"
    dim_date only one optionally to zero or more fact_shipment_cycle : "loading_date = date_sk"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
