# The Credits Roll

*Searchable from every angle. Design it so nothing gets lost.*

[Data Modeling · Hard · on DataDriven](https://datadriven.io/problems/the_credits_roll)

## How it went

| | |
|---|---|
| Solved | 2026-10-12 |
| Accepted | on the 2nd submission |
| Hints | none |
| Concepts | Attributes, Constraints, Data Types, Entities, 1NF, Foreign Keys, Junction Tables, Many-to-Many, Primary Keys, 2NF, Surrogate Keys, 3NF |

## The design

```mermaid
erDiagram
    dim_film {
        INT film_id PK
        CHAR title
        INT released_year
        CHAR genre
    }
    dim_person {
        INT person_id PK
        CHAR name
        DATE dob
        CHAR country
    }
    bridge_film_credit {
        INT credit_id PK
        INT film_id PK
        INT person_id PK
        INT order_id PK
        CHAR production_role
        CHAR character_name
        INT billing_order
    }
    dim_order {
        INT order_id PK
        DECIMAL amount
        DATE order_date
    }
    dim_film only one to zero or more bridge_film_credit : "film_id"
    dim_person only one to zero or more bridge_film_credit : "person_id"
    dim_order only one to zero or more bridge_film_credit : "order_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
