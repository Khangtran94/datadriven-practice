# The Gift Economy

*Someone goes live, thousands tune in, chat explodes, and virtual gifts start flying.*

[Data Modeling · Medium · on DataDriven](https://datadriven.io/problems/the_gift_economy)

## How it went

| | |
|---|---|
| Solved | 2026-10-16 |
| Accepted | on the 2nd submission |
| Hints | none |
| Concepts | Attributes, Cardinality, Constraints, Data Types, Dimension Tables, Entities, Fact Tables, 1NF, Foreign Keys, Grain Definition, Junction Tables, Many-to-Many, One-to-Many, Primary Keys, 2NF, Star Schema, 3NF |

## The design

```mermaid
erDiagram
    dim_creator {
        INT creator_id PK
        CHAR name
        CHAR phone
        CHAR email
    }
    dim_viewer {
        INT viewer_id PK
        CHAR name
        CHAR phone
        CHAR email
    }
    chat_message {
        INT chat_id PK
        INT session_id FK
        TIMESTAMP message_time
        VARCHAR message
    }
    stream {
        INT stream_id PK
        INT date_stream FK
        INT category_id FK
        INT creator_id FK
        TIMESTAMP start_time
        TIMESTAMP end_time
    }
    viewer_session {
        INT session_id PK
        INT stream_id FK
        INT viewer_id FK
        TIMESTAMP join_time
        TIMESTAMP leave_time
    }
    gift {
        INT gift_event PK
        INT session_id FK
        FLOAT dollar_amount
        TIMESTAMP send_time
        VARCHAR gift_name
        CHAR gift_purchase
    }
    stream_category {
        INT category_id PK
        CHAR genre
        CHAR name
    }
    dim_date {
        INT date_sk PK
        DATE full_date
        INT month
        INT year
    }
    stream only one optionally to zero or more viewer_session : "stream_id"
    dim_date only one optionally to zero or more stream : "date_stream = date_sk"
    dim_viewer only one optionally to zero or more viewer_session : "viewer_id"
    viewer_session only one optionally to zero or more chat_message : "session_id"
    dim_creator only one optionally to zero or more stream : "creator_id"
    stream_category only one optionally to zero or more stream : "category_id"
    viewer_session only one optionally to zero or more gift : "session_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
