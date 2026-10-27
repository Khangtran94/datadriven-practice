# A Number for the Seller

*They want a total. Give them the right schema first.*

[Data Modeling · Easy · on DataDriven](https://datadriven.io/problems/a_number_for_the_seller)

## How it went

| | |
|---|---|
| Solved | 2026-10-27 |
| Accepted | on the 7th submission |
| Hints | none |
| Concepts | Attributes, Dimension Tables, Fact Tables, Foreign Keys, Grain Definition, Metric Additivity, One-to-Many, Pre-Aggregation, Primary Keys, Star Schema, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_product {
        INT product_id PK
        CHAR name
        BOOLEAN is_active
        DATE date_listed
        DATE effective_from
        DATE effective_to
    }
    dim_seller {
        INT seller_id PK
        CHAR name
    }
    fact_event {
        INT event_id PK
        INT product_id FK
        INT seller_id FK
        INT event_date
        CHAR action
        INT units_sold
        INT revenue
    }
    daily_dashboard {
        INT seller_id PK
        INT date PK
        INT active_count
        INT daily_revenue
        INT daily_unit_sales
    }
    dim_date {
        INT date_id PK
        INT day
        INT month
        INT year
    }
    dim_product only one optionally to zero or more fact_event : "product_id"
    dim_seller only one optionally to zero or more fact_event : "seller_id"
    dim_seller only one to zero or more daily_dashboard : "seller_id"
    dim_date only one to zero or more daily_dashboard : "date = date_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
