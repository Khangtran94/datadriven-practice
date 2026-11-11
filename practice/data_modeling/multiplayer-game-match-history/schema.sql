CREATE TABLE dim_date (
    date_sk INT,
    month INT,
    year INT,
    full_date DATE,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_player (
    signup_date INT,
    player_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    country CHAR,
    region CHAR,
    PRIMARY KEY (player_id)
);

CREATE TABLE fact_match (
    match_id INT,
    match_day INT,
    match_time TIMESTAMP,
    match_type CHAR,
    home_team_name CHAR,
    away_team_name CHAR,
    home_team_score INT,
    away_team_score INT,
    team_win CHAR,
    PRIMARY KEY (match_id)
);

CREATE TABLE match_player_stat (
    match_id INT,
    player_id INT,
    player_score INT,
    minutes_played DECIMAL,
    PRIMARY KEY (match_id, player_id)
);

CREATE TABLE summary_stat (
    summary_id INT,
    from_date INT,
    to_date INT,
    number_of_match INT,
    number_of_player INT,
    avg_score_player DECIMAL,
    PRIMARY KEY (summary_id)
);

CREATE TABLE player_stat (
    player_id INT,
    total_match INT,
    avg_score DECIMAL,
    PRIMARY KEY (player_id)
);

CREATE TABLE leaderboard (
    player_id INT,
    score INT,
    ranking INT,
    PRIMARY KEY (player_id)
);

ALTER TABLE fact_match
    ADD FOREIGN KEY (match_day) REFERENCES dim_date (date_sk);

ALTER TABLE match_player_stat
    ADD FOREIGN KEY (match_id) REFERENCES fact_match (match_id);

ALTER TABLE match_player_stat
    ADD FOREIGN KEY (player_id) REFERENCES dim_player (player_id);

ALTER TABLE summary_stat
    ADD FOREIGN KEY (from_date) REFERENCES dim_date (date_sk);

ALTER TABLE summary_stat
    ADD FOREIGN KEY (to_date) REFERENCES dim_date (date_sk);

ALTER TABLE dim_player
    ADD FOREIGN KEY (signup_date) REFERENCES dim_date (date_sk);

ALTER TABLE player_stat
    ADD FOREIGN KEY (player_id) REFERENCES dim_player (player_id);

ALTER TABLE leaderboard
    ADD FOREIGN KEY (player_id) REFERENCES player_stat (player_id);
