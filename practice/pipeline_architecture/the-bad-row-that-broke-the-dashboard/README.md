# The Bad Row That Broke the Dashboard

*Bad records cannot reach the warehouse.*

[Pipeline Architecture · Medium · on DataDriven](https://datadriven.io/problems/the_bad_row_that_broke_the_dashboard)

## How it went

| | |
|---|---|
| Solved | 2026-08-27 |
| Accepted | on the 3rd submission |
| Time | under a minute |
| Hints | none |
| Concepts | Batch vs Streaming, Data Quality & Validation, Dead Letter Queues, Event-Driven Architecture, Event Streaming Platforms, Idempotency, Pipeline Monitoring, Retry & Failure Handling, Spark Execution Model, Stream Processing |

## The design

```mermaid
flowchart LR
    n1[("<b>Source</b><br/>Kafka<br/>application event")]
    n2["<b>Transform</b><br/>Flink<br/>streaming process"]
    n3{{"<b>Quality</b><br/>check validation"}}
    n4[/"<b>Queue</b><br/>Dead letter queue"/]
    n5[("<b>Storage</b><br/>Snowflake<br/>data warehouse production table")]
    n6("<b>Consumer</b><br/>Grafana<br/>dashboard")
    n7["<b>Transform</b><br/>AWS Glue Schema Registry<br/>schema registry"]
    n2 --> n3
    n3 -.->|"Error path: fail validation"| n4
    n3 --> n5
    n5 --> n6
    n1 --> n7
    n7 --> n2
    classDef source fill:#1B3D2E,stroke:#34D399,color:#34D399
    classDef transform fill:#1E3A5F,stroke:#5B8DEF,color:#5B8DEF
    classDef storage fill:#2A2348,stroke:#A78BFA,color:#A78BFA
    classDef quality_gate fill:#3A3020,stroke:#FBBF24,color:#FBBF24
    classDef consumer fill:#1E3A5F,stroke:#94A3B8,color:#94A3B8
    classDef queue fill:#1A3A40,stroke:#22D3EE,color:#22D3EE
    class n1 source
    class n2,n7 transform
    class n5 storage
    class n3 quality_gate
    class n6 consumer
    class n4 queue
    linkStyle 0 stroke:#3B82F6
    linkStyle 1 stroke:#DC2626,stroke-dasharray:7 5
    linkStyle 2 stroke:#3B82F6
    linkStyle 3 stroke:#3B82F6
    linkStyle 4 stroke:#3B82F6
    linkStyle 5 stroke:#3B82F6
```

The whole design, with every component's settings, the connections, the zones and where each sits on the canvas, is in [`architecture.json`](./architecture.json).
