# Who Comes Back

[Data Modeling · Medium · on DataDriven](https://datadriven.io/problems/who_comes_back)

## How it went

| | |
|---|---|
| Solved | 2026-10-29 |
| Accepted | on the 3rd submission |
| Hints | none |
| Concepts | Dimension Tables, Fact Tables, Foreign Keys, Grain Definition, Metric Additivity, One-to-Many, Pre-Aggregation, Primary Keys, Star Schema, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_date {
        DATE date_sk PK
        INT month
        INT year
    }
    dim_user {
        INT user_id PK
        DATE signup_date FK
        INT channel_id FK
        INT username
        INT phone
        CHAR email
    }
    summary_user {
        DATE date_sk PK
        INT user_id PK
        INT number_of_session
        INT number_of_video_watched
        DECIMAL watch_time
    }
    dim_channel {
        INT channel_id PK
        CHAR name
        CHAR type
    }
    dim_date only one optionally to zero or more dim_user : "signup_date = date_sk"
    dim_user only one to zero or more summary_user : "user_id"
    dim_date only one to zero or more summary_user : "date_sk"
    dim_channel only one optionally to zero or more dim_user : "channel_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
