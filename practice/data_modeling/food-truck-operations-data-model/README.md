# Food Truck Operations Data Model

*Mobile vendor, fixed menu, unpredictable locations.*

[Data Modeling · Medium · on DataDriven](https://datadriven.io/problems/food_truck_operations_data_model)

## How it went

| | |
|---|---|
| Solved | 2026-10-29 |
| Accepted | on the first submission |
| Hints | none |
| Concepts | Dimension Tables, Fact Tables, Foreign Keys, Grain Definition, Junction Tables, Many-to-Many, Metric Additivity, One-to-Many, Primary Keys, Star Schema, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_date {
        DATE date_sk PK
        INT month
        INT year
    }
    dim_truck {
        INT truck_id PK
        INT license_plate
    }
    dim_food {
        INT menu_food_id PK
        INT menu_id FK
        CHAR food_name
        DECIMAL price
    }
    food_order {
        INT order_id PK
        DATE order_date FK
        INT location_id FK
        INT truck_id FK
        DECIMAL total_revenue
        CHAR status
    }
    dim_location {
        INT location_id PK
        CHAR street
        CHAR city
    }
    dim_menu {
        INT menu_id PK
        CHAR menu_name
    }
    order_detail {
        INT order_line_id PK
        INT menu_food_id FK
        INT order_id FK
        INT quantity
        DECIMAL amount
    }
    dim_date only one optionally to zero or more food_order : "order_date = date_sk"
    dim_location only one optionally to zero or more food_order : "location_id"
    dim_truck only one optionally to zero or more food_order : "truck_id"
    food_order only one optionally to zero or more order_detail : "order_id"
    dim_menu only one optionally to zero or more dim_food : "menu_id"
    dim_food only one optionally to zero or more order_detail : "menu_food_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
