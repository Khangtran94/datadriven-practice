# Lateral Paths

*People switch teams. HR loses track.*

[Data Modeling · Medium · on DataDriven](https://datadriven.io/problems/lateral_paths)

## How it went

| | |
|---|---|
| Solved | 2026-10-12 |
| Accepted | on the 2nd submission |
| Hints | none |
| Concepts | Attributes, Composite Keys, Constraints, Data Types, Entities, Foreign Keys, Grain Definition, Junction Tables, Many-to-Many, One-to-Many, Primary Keys, SCD Type 2, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_team {
        INT team_id PK
        INT office_id FK
        INT manager_id FK
        CHAR department_id FK
        INT floor
        CHAR name
        INT number_members
    }
    dim_manager {
        INT manager_id PK
        CHAR name
        CHAR phone
        CHAR email
    }
    dim_office {
        INT office_id PK
        CHAR name
        CHAR city
        CHAR address
    }
    dim_employee {
        INT employee_id PK
        CHAR name
        CHAR phone
        CHAR email
        DATE joined_at
    }
    transfer_log {
        INT log_id PK
        INT date_sk FK
        INT employee_id FK
        INT from_team_id FK
        INT to_team_id FK
        BOOLEAN is_current
    }
    dim_date {
        INT date_sk PK
        DATE full_date
        INT day
        INT month
        INT year
    }
    dim_org {
        INT org_id PK
        CHAR name
    }
    dim_division {
        INT division_id PK
        INT org_id FK
        CHAR name
    }
    dim_department {
        INT department_id PK
        INT division_id FK
        CHAR name
    }
    dim_office only one optionally to zero or more dim_team : "office_id"
    dim_manager only one optionally to zero or more dim_team : "manager_id"
    dim_employee only one optionally to zero or more transfer_log : "employee_id"
    dim_date only one optionally to zero or more transfer_log : "date_sk"
    dim_team only one optionally to zero or more transfer_log : "from_team_id = team_id"
    dim_team only one optionally to zero or more transfer_log : "to_team_id = team_id"
    dim_department only one optionally to zero or more dim_team : "department_id"
    dim_division only one optionally to zero or more dim_department : "division_id"
    dim_org only one optionally to zero or more dim_division : "org_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
