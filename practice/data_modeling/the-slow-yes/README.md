# The Slow Yes

[Data Modeling · Hard · on DataDriven](https://datadriven.io/problems/the_slow_yes)

## How it went

| | |
|---|---|
| Solved | 2026-10-27 |
| Accepted | on the 3rd submission |
| Hints | none |
| Concepts | Cardinality, Columnar Storage, Constraints, Denormalization, Dimension Tables, Fact Tables, Foreign Keys, Grain Definition, Immutable Logs, Indexing, Late-Arriving Data, Metric Additivity, One-to-Many, Primary Keys, Star Schema, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_date {
        DATE date_sk PK
        INT month
        INT year
    }
    dim_campaign {
        INT campaign_id PK
        CHAR name
        CHAR campaign_type
    }
    dim_device {
        INT device_id PK
        INT region_id FK
        CHAR name
        CHAR device_type
    }
    dim_region {
        INT region_id PK
        CHAR name
    }
    fact_event {
        INT event_id PK
        DATE event_date FK
        INT ad_id FK
        INT device_id FK
        TIMESTAMP event_time
        CHAR event_type
        INT impression_id UK
    }
    report_analytic {
        DATE date_report PK
        INT ad_id PK
        INT impression_count
        INT click_count
        INT conversion_count
    }
    dim_ad {
        INT ad_id PK
        INT campaign_id FK
        CHAR ad_name
    }
    fact_conversion {
        INT conversion_id PK
        INT impression_id FK
        DECIMAL amount
    }
    dim_region only one optionally to zero or more dim_device : "region_id"
    dim_device only one optionally to zero or more fact_event : "device_id"
    dim_date only one optionally to zero or more fact_event : "event_date = date_sk"
    dim_date only one to zero or more report_analytic : "date_report = date_sk"
    dim_campaign only one optionally to zero or more dim_ad : "campaign_id"
    dim_ad only one to zero or more report_analytic : "ad_id"
    dim_ad only one optionally to zero or more fact_event : "ad_id"
    fact_event only one optionally to zero or more fact_conversion : "impression_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
