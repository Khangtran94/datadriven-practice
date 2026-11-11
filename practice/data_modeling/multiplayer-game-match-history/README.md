# Multiplayer Game Match History

*Millions of matches. The leaderboard refreshes in 15 minutes.*

[Data Modeling · Medium · on DataDriven](https://datadriven.io/problems/multiplayer_game_match_history)

## How it went

| | |
|---|---|
| Solved | 2026-11-11 |
| Accepted | on the first submission |
| Hints | none |
| Concepts | Attributes, Dimension Tables, Entities, Fact Tables, Foreign Keys, Grain Definition, Many-to-Many, Metric Additivity, One-to-Many, Pre-Aggregation, Primary Keys, Star Schema, Surrogate Keys |

## The design

```mermaid
erDiagram
    dim_date {
        INT date_sk PK
        INT month
        INT year
        DATE full_date
    }
    dim_player {
        INT signup_date FK
        INT player_id PK
        CHAR name
        CHAR phone
        CHAR email
        CHAR country
        CHAR region
    }
    fact_match {
        INT match_id PK
        INT match_day FK
        TIMESTAMP match_time
        CHAR match_type
        CHAR home_team_name
        CHAR away_team_name
        INT home_team_score
        INT away_team_score
        CHAR team_win
    }
    match_player_stat {
        INT match_id PK
        INT player_id PK
        INT player_score
        DECIMAL minutes_played
    }
    summary_stat {
        INT summary_id PK
        INT from_date FK
        INT to_date FK
        INT number_of_match
        INT number_of_player
        DECIMAL avg_score_player
    }
    player_stat {
        INT player_id PK
        INT total_match
        DECIMAL avg_score
    }
    leaderboard {
        INT player_id PK
        INT score
        INT ranking
    }
    dim_date only one optionally to zero or more fact_match : "match_day = date_sk"
    fact_match only one to zero or more match_player_stat : "match_id"
    dim_player only one to zero or more match_player_stat : "player_id"
    dim_date only one optionally to zero or more summary_stat : "from_date = date_sk"
    dim_date only one optionally to zero or more summary_stat : "to_date = date_sk"
    dim_date only one optionally to zero or more dim_player : "signup_date = date_sk"
    dim_player only one to zero or more player_stat : "player_id"
    player_stat only one to zero or more leaderboard : "player_id"
```

The accepted design is in [`schema.sql`](./schema.sql) as DDL and in [`schema.json`](./schema.json) as JSON.
