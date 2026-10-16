# Crossing Over

[Data Modeling · Medium · on DataDriven](https://datadriven.io/problems/crossing_over)

## How it went

| | |
|---|---|
| Solved | 2026-10-16 |
| Accepted | on the 2nd submission |
| Hints | none |
| Concepts | Constraints, Dimension Tables, Fact Tables, Foreign Keys, Grain Definition, Junction Tables, Many-to-Many, One-to-Many, Primary Keys, SCD Strategy, SCD Type 2, Star Schema, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_date {
        INT date_sk PK
        DATE full_date
        INT month
        INT year
    }
    dim_patient {
        INT patient_id PK
        CHAR name
        CHAR phone
        CHAR email
    }
    fact_adverse_event {
        INT event_id PK
        INT event_date FK
        INT patient_id FK
        CHAR adverse_type
    }
    patient_arm {
        INT arm_id PK
        INT treatment_date FK
        INT patient_id FK
        DECIMAL dose
    }
    dim_date only one optionally to zero or more fact_adverse_event : "event_date = date_sk"
    dim_patient only one optionally to zero or more fact_adverse_event : "patient_id"
    dim_date only one optionally to zero or more patient_arm : "treatment_date = date_sk"
    dim_patient only one optionally to zero or more patient_arm : "patient_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
