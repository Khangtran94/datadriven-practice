# The Endless Thread

*Follows, likes, replies to replies. It never stops.*

[Data Modeling · Medium · on DataDriven](https://datadriven.io/problems/the_endless_thread)

## How it went

| | |
|---|---|
| Solved | 2026-10-13 |
| Accepted | on the 4th submission |
| Hints | none |
| Concepts | Attributes, Composite Keys, Constraints, Entities, 1NF, Foreign Keys, Grain Definition, Junction Tables, Many-to-Many, Metric Additivity, One-to-Many, Primary Keys, 2NF, Self-Referential, Surrogate Keys, 3NF |

## The design

```mermaid
erDiagram
    dim_user {
        INT user_id PK
        CHAR name
        CHAR phone
        CHAR email
    }
    dim_creator {
        INT creator_id PK
        CHAR name
        CHAR phone
        CHAR email
    }
    dim_date {
        INT date_sk PK
        DATE full_date
        INT month
        INT year
    }
    bridge_follow {
        INT follow_date PK
        INT create_id PK
        INT user_id PK
    }
    dim_post {
        INT post_id PK
        INT creator_id FK
        CHAR post_type
        CHAR content
    }
    like_post {
        INT like_id PK
        INT user_id PK
        INT post_id PK
        TIMESTAMP like_time
    }
    comment_table {
        INT comment_id PK
        INT user_id FK
        INT post_id FK
        CHAR content
        TIMESTAMP comment_time
    }
    reply_table {
        INT reply_id PK
        INT reply_from_comment_id FK
        INT user_id FK
        CHAR content
        TIMESTAMP reply_time
    }
    dim_user only one to zero or more bridge_follow : "user_id"
    dim_creator only one to zero or more bridge_follow : "create_id = creator_id"
    dim_date only one to zero or more bridge_follow : "follow_date = date_sk"
    dim_creator only one optionally to zero or more dim_post : "creator_id"
    dim_post only one to zero or more like_post : "post_id"
    dim_user only one to zero or more like_post : "user_id"
    dim_post only one optionally to zero or more comment_table : "post_id"
    dim_user only one optionally to zero or more comment_table : "user_id"
    comment_table only one optionally to zero or more reply_table : "reply_from_comment_id = comment_id"
    dim_user only one optionally to zero or more reply_table : "user_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
