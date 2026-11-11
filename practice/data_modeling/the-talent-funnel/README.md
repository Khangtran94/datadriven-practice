# The Talent Funnel

*Thousands applied. One accepted. Where did the rest go?*

[Data Modeling · Medium · on DataDriven](https://datadriven.io/problems/the_talent_funnel)

## How it went

| | |
|---|---|
| Solved | 2026-11-11 |
| Accepted | on the 2nd submission |
| Hints | none |
| Concepts | Dimension Tables, Fact Tables, Foreign Keys, Grain Definition, Metric Additivity, One-to-Many, Pre-Aggregation, Star Schema, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_date {
        INT date_sk PK
        DATE full_date
        INT month
        INT year
    }
    dim_candidate {
        INT candidate_id PK
        INT date_of_birth FK
        CHAR name
        CHAR phone
        CHAR email
        CHAR country
    }
    dim_job {
        INT job_id PK
        INT date_listed_job FK
        INT date_expired_job FK
        CHAR job_title
        CHAR company_name
        CHAR job_type
        CHAR location
    }
    fact_application_lifecycle {
        INT application_id PK
        INT job_id FK
        INT candidate_id FK
        INT date_view FK
        INT date_apply_resume FK
        INT date_interview FK
        INT date_offer FK
        INT channel_reach_id FK
        CHAR current_status
    }
    dim_channel {
        INT channel_id PK
        CHAR channel_name
        CHAR channel_type
    }
    dim_date only one optionally to zero or more dim_candidate : "date_of_birth = date_sk"
    dim_date only one optionally to zero or more dim_job : "date_listed_job = date_sk"
    dim_date only one optionally to zero or more dim_job : "date_expired_job = date_sk"
    dim_job only one optionally to zero or more fact_application_lifecycle : "job_id"
    dim_candidate only one optionally to zero or more fact_application_lifecycle : "candidate_id"
    dim_date only one optionally to zero or more fact_application_lifecycle : "date_view = date_sk"
    dim_date only one optionally to zero or more fact_application_lifecycle : "date_apply_resume = date_sk"
    dim_date only one optionally to zero or more fact_application_lifecycle : "date_interview = date_sk"
    dim_date only one optionally to zero or more fact_application_lifecycle : "date_offer = date_sk"
    dim_channel only one optionally to zero or more fact_application_lifecycle : "channel_reach_id = channel_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
