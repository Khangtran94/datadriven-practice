# Every Line Remembered

*Customers move, products relaunch, and some stores have no address. Reshape the tables so nothing gets forgotten.*

[Data Modeling · Medium · on DataDriven](https://datadriven.io/problems/every_line_remembered)

## How it went

| | |
|---|---|
| Solved | 2026-10-31 |
| Accepted | on the first submission |
| Hints | none |
| Concepts | Attributes, Denormalization, Dimension Tables, Entities, Fact Tables, Foreign Keys, Grain Definition, Metric Additivity, One-to-Many, Primary Keys, Star Schema, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_date {
        DATE date_sk PK
        INT month
        INT year
    }
    dim_customer {
        INT customer_sk PK
        INT customer_id
        CHAR name
        CHAR phone
        CHAR email
        CHAR city
        DATE effective_from FK
        DATE effective_to FK
        BOOLEAN is_active
    }
    dim_product {
        INT product_sk PK
        INT product_id
        CHAR name
        CHAR type
        DATE effective_from FK
        DATE effective_to FK
        BOOLEAN is_active
        DECIMAL price
    }
    dim_employee {
        INT employee_id PK
        CHAR name
        CHAR phone
        CHAR email
        DATE date_joined FK
    }
    dim_store {
        INT store_id PK
        CHAR name
        CHAR address
        CHAR city
    }
    fact_order {
        DATE order_date FK
        INT order_id PK
        INT customer_sk FK
        INT store_id FK
        INT employee_id FK
        DECIMAL total_amount
    }
    fact_order_line {
        INT order_line_sk PK
        INT order_id FK
        INT product_sk FK
        INT quantity
        DECIMAL amount
    }
    dim_date only one optionally to zero or more dim_customer : "effective_from = date_sk"
    dim_date only one optionally to zero or more dim_customer : "effective_to = date_sk"
    dim_date only one optionally to zero or more dim_product : "effective_to = date_sk"
    dim_date only one optionally to zero or more dim_product : "effective_from = date_sk"
    dim_date only one optionally to zero or more dim_employee : "date_joined = date_sk"
    dim_store only one optionally to zero or more fact_order : "store_id"
    dim_date only one optionally to zero or more fact_order : "order_date = date_sk"
    fact_order only one optionally to zero or more fact_order_line : "order_id"
    dim_customer only one optionally to zero or more fact_order : "customer_sk"
    dim_product only one optionally to zero or more fact_order_line : "product_sk"
    dim_employee only one optionally to zero or more fact_order : "employee_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
