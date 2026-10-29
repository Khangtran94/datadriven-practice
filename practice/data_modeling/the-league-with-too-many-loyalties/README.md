# The League With Too Many Loyalties

*A player can belong to many teams. The schema must agree.*

[Data Modeling · Hard · on DataDriven](https://datadriven.io/problems/the_league_with_too_many_loyalties)

## How it went

| | |
|---|---|
| Solved | 2026-10-29 |
| Accepted | on the 8th submission |
| Hints | none |
| Concepts | Attributes, Composite Keys, Constraints, Dimension Tables, Entities, Fact Tables, Foreign Keys, Grain Definition, Junction Tables, Many-to-Many, Metric Additivity, One-to-Many, Pre-Aggregation, Primary Keys, SCD Strategy, SCD Type 2, Star Schema, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_team {
        INT team_id PK
        INT league_id FK
        CHAR name
        CHAR team_type
        CHAR player_capacity
    }
    dim_player {
        INT player_id PK
        DATE date_of_birth
        CHAR name
        CHAR phone
        CHAR email
        CHAR positition
    }
    dim_tournament {
        INT tournament_id PK
        DATE date_start
        DATE date_end
        INT number_of_team
    }
    match_player_detail {
        INT match_id PK
        INT player_id PK
        INT minutes_played
        INT goal
        INT assist
        INT shot
        DECIMAL pass_completed_percentage
        DECIMAL run_distance
        BOOLEAN yellow_card
        BOOLEAN red_card
    }
    tournament_match {
        INT match_id PK
        DATE match_date
        INT stadium_id FK
        INT home_team_id FK
        INT away_team_id FK
        INT home_team_score
        INT away_team_score
    }
    dim_stadium {
        INT stadium_id PK
        CHAR name
        INT seat_capacity
    }
    bridge_team_player {
        INT player_team_sk PK
        INT team_id FK
        INT player_id FK
    }
    bridge_team_tournament {
        INT team_tournament_sk PK
        INT tournament_id FK
        INT team_id FK
    }
    dim_league {
        INT league_id PK
        CHAR league_name
    }
    tournament_match only one to zero or more match_player_detail : "match_id"
    dim_team only one optionally to zero or more bridge_team_player : "team_id"
    dim_player only one optionally to zero or more bridge_team_player : "player_id"
    dim_team only one optionally to zero or more bridge_team_tournament : "team_id"
    dim_tournament only one optionally to zero or more bridge_team_tournament : "tournament_id"
    bridge_team_tournament only one optionally to zero or more tournament_match : "home_team_id = team_tournament_sk"
    bridge_team_tournament only one optionally to zero or more tournament_match : "away_team_id = team_tournament_sk"
    dim_stadium only one optionally to zero or more tournament_match : "stadium_id"
    dim_player only one to zero or more match_player_detail : "player_id"
    dim_league only one optionally to zero or more dim_team : "league_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
