# Property Booking Platform

*Five-star listing. Three-star reality.*

[Data Modeling · Hard · on DataDriven](https://datadriven.io/problems/property_booking_platform)

## How it went

| | |
|---|---|
| Solved | 2026-10-28 |
| Accepted | on the first submission |
| Hints | none |
| Concepts | Attributes, Composite Keys, Constraints, Data Types, Denormalization, Dimension Tables, Fact Tables, Foreign Keys, Grain Definition, Indexing, Junction Tables, Key Generation, Many-to-Many, Metric Additivity, One-to-Many, Pre-Aggregation, Primary Keys, SCD Strategy, SCD Type 2, Star Schema, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_date {
        DATE date_sk PK
        INT month
        INT year
    }
    dim_property {
        INT property_id PK
        INT host_id FK
        CHAR name
        CHAR type
    }
    dim_host {
        INT host_id PK
        DATE signup_at FK
        CHAR name
        CHAR phone
        CHAR email
    }
    dim_guest {
        INT guest_id PK
        DATE signup_at FK
        CHAR name
        CHAR phone
        CHAR email
    }
    event_log {
        INT event_id PK
        DATE event_date FK
        INT guest_id FK
        INT property_id FK
        DECIMAL number_day_booked
        DECIMAL amount
    }
    analysis {
        INT analysis_id PK
        DATE analysis_date FK
        INT event_id FK
        DECIMAL guest_satisfaction_score
        VARCHAR guest_review
        DECIMAL property_score
        DECIMAL rating
    }
    dim_date only one optionally to zero or more dim_host : "signup_at = date_sk"
    dim_date only one optionally to zero or more dim_guest : "signup_at = date_sk"
    dim_host only one optionally to zero or more dim_property : "host_id"
    dim_date only one optionally to zero or more event_log : "event_date = date_sk"
    dim_guest only one optionally to zero or more event_log : "guest_id"
    dim_property only one optionally to zero or more event_log : "property_id"
    event_log only one optionally to zero or more analysis : "event_id"
    dim_date only one optionally to zero or more analysis : "analysis_date = date_sk"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
