# Between the Cameras

*Every plate that goes in should come out. Watch the ones that don't.*

[Data Modeling · Easy · on DataDriven](https://datadriven.io/problems/between_the_cameras)

## How it went

| | |
|---|---|
| Solved | 2026-10-27 |
| Accepted | on the first submission |
| Hints | none |
| Concepts | Attributes, Constraints, Data Types, Entities, Foreign Keys, Grain Definition, One-to-Many, Pre-Aggregation, Primary Keys |

## The design

```mermaid
erDiagram
    dim_plate {
        INT plate_id PK
        CHAR plate_character
        CHAR car_brand
        CHAR car_color
    }
    dim_date {
        DATE date_sk PK
        INT month
        INT year
    }
    fact_event {
        INT event_id PK
        DATE event_date FK
        INT plate_id FK
        INT section_id FK
        TIMESTAMP entry_time
        TIMESTAMP exit_time
        BOOLEAN exit_status
    }
    dim_section {
        INT section_id PK
        CHAR section_name
        CHAR location
    }
    dim_date only one optionally to zero or more fact_event : "event_date = date_sk"
    dim_plate only one optionally to zero or more fact_event : "plate_id"
    dim_section only one optionally to zero or more fact_event : "section_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
