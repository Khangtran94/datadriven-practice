# The Anonymous Majority

*Millions of clicks, mostly anonymous.*

[Data Modeling · Medium · on DataDriven](https://datadriven.io/problems/the_anonymous_majority)

## How it went

| | |
|---|---|
| Solved | 2026-10-28 |
| Accepted | on the 3rd submission |
| Hints | none |
| Concepts | Denormalization, Dimension Tables, Fact Tables, Foreign Keys, Grain Definition, Immutable Logs, Indexing, Medallion Architecture, Metric Additivity, One-to-Many, Pre-Aggregation, Primary Keys, Star Schema, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_date {
        DATE date_sk PK
        INT month
        INT year
    }
    dim_shopper {
        INT shopper_id PK
        DATE signup_date FK
        CHAR shopper_account
        CHAR phone
        CHAR email
    }
    dim_device {
        INT device_id PK
        DATE signup_at FK
        CHAR device_type
        CHAR brand
    }
    fact_event {
        INT event_id PK
        INT product_id FK
        INT session_id FK
        INT element_id FK
        INT page_id FK
        TIMESTAMP event_time
        CHAR action_type
        CHAR link_URL
        CHAR color
        CHAR size
    }
    fact_session {
        INT session_id PK
        DATE session_date FK
        INT shopper_id FK
        INT device_id FK
        TIMESTAMP start_time
        TIMESTAMP end_time
        BOOLEAN is_purchased
        INT event_count
        INT product_views
    }
    dim_product {
        INT product_id PK
        CHAR name
        CHAR genre
    }
    dim_page {
        INT page_id PK
        CHAR page_url
        CHAR page_type
    }
    dim_element {
        INT element_id PK
        CHAR name
        CHAR type
    }
    dim_date only one optionally to zero or more dim_shopper : "signup_date = date_sk"
    dim_date only one optionally to zero or more dim_device : "signup_at = date_sk"
    dim_date only one optionally to zero or more fact_session : "session_date = date_sk"
    dim_shopper only one optionally to zero or more fact_session : "shopper_id"
    dim_device only one optionally to zero or more fact_session : "device_id"
    fact_session only one optionally to zero or more fact_event : "session_id"
    dim_product only one optionally to zero or more fact_event : "product_id"
    dim_page only one optionally to zero or more fact_event : "page_id"
    dim_element only one optionally to zero or more fact_event : "element_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
