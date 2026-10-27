# Deal Flow

*Sellers want buyers. Buyers want deals.*

[Data Modeling · Medium · on DataDriven](https://datadriven.io/problems/deal_flow)

## How it went

| | |
|---|---|
| Solved | 2026-10-27 |
| Accepted | on the first submission |
| Hints | none |
| Concepts | Attributes, Constraints, Denormalization, Dimension Tables, Entities, Fact Tables, Foreign Keys, Grain Definition, Many-to-Many, Metric Additivity, OLAP Cubes, One-to-Many, Primary Keys, Star Schema, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_buyer {
        INT buyer_id PK
        CHAR name
        CHAR phone
        CHAR email
    }
    dim_property {
        INT property_id PK
        INT neighborhood_id FK
        CHAR name
        CHAR property_type
    }
    dim_neighborhood {
        INT neighborhood_id PK
        CHAR city
        CHAR state
    }
    dim_date {
        DATE date_sk PK
        INT month
        INT year
    }
    fact_event {
        INT event_id PK
        DATE event_date FK
        TIMESTAMP event_time
        INT buyer_id FK
        INT property_id FK
        CHAR action
    }
    dim_neighborhood only one optionally to zero or more dim_property : "neighborhood_id"
    dim_date only one optionally to zero or more fact_event : "event_date = date_sk"
    dim_buyer only one optionally to zero or more fact_event : "buyer_id"
    dim_property only one optionally to zero or more fact_event : "property_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
