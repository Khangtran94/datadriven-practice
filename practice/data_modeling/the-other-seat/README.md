# The Other Seat

[Data Modeling · Hard · on DataDriven](https://datadriven.io/problems/the_other_seat)

## How it went

| | |
|---|---|
| Solved | 2026-10-27 |
| Accepted | on the first submission |
| Hints | none |
| Concepts | Attributes, Constraints, Data Types, Dimension Tables, Entities, Fact Tables, 1NF, Foreign Keys, Grain Definition, Key Generation, Metric Additivity, OLAP Cubes, One-to-Many, One-to-One, Primary Keys, 2NF, Star Schema, Surrogate Keys, 3NF |

## The design

```mermaid
erDiagram
    dim_user {
        INT user_id PK
        DATE signup_at FK
        CHAR name
        CHAR phone
        CHAR email
    }
    dim_date {
        DATE date_sk PK
        INT month
        INT year
    }
    dim_vehicle {
        INT vehicle_id PK
        CHAR vehicle_type
        CHAR brand
        CHAR license_plate
    }
    dim_trip {
        INT trip_id PK
        CHAR from_place
        CHAR to_place
        DECIMAL fare_charged
    }
    fact_event {
        INT event_id PK
        DATE event_date FK
        INT trip_id FK
        INT driver_id FK
        INT rider_id FK
        INT vehicle_id FK
        CHAR direction
        DECIMAL surge_mutliplier
        DECIMAL rating
    }
    dim_date only one optionally to zero or more dim_user : "signup_at = date_sk"
    dim_date only one optionally to zero or more fact_event : "event_date = date_sk"
    dim_trip only one optionally to zero or more fact_event : "trip_id"
    dim_user only one optionally to zero or more fact_event : "driver_id = user_id"
    dim_user only one optionally to zero or more fact_event : "rider_id = user_id"
    dim_vehicle only one optionally to zero or more fact_event : "vehicle_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
