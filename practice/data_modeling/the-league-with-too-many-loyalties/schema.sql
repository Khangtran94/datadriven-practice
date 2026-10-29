CREATE TABLE dim_team (
    team_id INT,
    league_id INT,
    name CHAR,
    team_type CHAR,
    player_capacity CHAR,
    PRIMARY KEY (team_id)
);

CREATE TABLE dim_player (
    player_id INT,
    date_of_birth DATE,
    name CHAR,
    phone CHAR,
    email CHAR,
    positition CHAR,
    PRIMARY KEY (player_id)
);

CREATE TABLE dim_tournament (
    tournament_id INT,
    date_start DATE,
    date_end DATE,
    number_of_team INT,
    PRIMARY KEY (tournament_id)
);

CREATE TABLE match_player_detail (
    match_id INT,
    player_id INT,
    minutes_played INT,
    goal INT,
    assist INT,
    shot INT,
    pass_completed_percentage DECIMAL,
    run_distance DECIMAL,
    yellow_card BOOLEAN,
    red_card BOOLEAN,
    PRIMARY KEY (match_id, player_id)
);

CREATE TABLE tournament_match (
    match_id INT,
    match_date DATE,
    stadium_id INT,
    home_team_id INT,
    away_team_id INT,
    home_team_score INT,
    away_team_score INT,
    PRIMARY KEY (match_id)
);

CREATE TABLE dim_stadium (
    stadium_id INT,
    name CHAR,
    seat_capacity INT,
    PRIMARY KEY (stadium_id)
);

CREATE TABLE bridge_team_player (
    player_team_sk INT,
    team_id INT,
    player_id INT,
    PRIMARY KEY (player_team_sk)
);

CREATE TABLE bridge_team_tournament (
    team_tournament_sk INT,
    tournament_id INT,
    team_id INT,
    PRIMARY KEY (team_tournament_sk)
);

CREATE TABLE dim_league (
    league_id INT,
    league_name CHAR,
    PRIMARY KEY (league_id)
);

ALTER TABLE match_player_detail
    ADD FOREIGN KEY (match_id) REFERENCES tournament_match (match_id);

ALTER TABLE bridge_team_player
    ADD FOREIGN KEY (team_id) REFERENCES dim_team (team_id);

ALTER TABLE bridge_team_player
    ADD FOREIGN KEY (player_id) REFERENCES dim_player (player_id);

ALTER TABLE bridge_team_tournament
    ADD FOREIGN KEY (team_id) REFERENCES dim_team (team_id);

ALTER TABLE bridge_team_tournament
    ADD FOREIGN KEY (tournament_id) REFERENCES dim_tournament (tournament_id);

ALTER TABLE tournament_match
    ADD FOREIGN KEY (home_team_id) REFERENCES bridge_team_tournament (team_tournament_sk);

ALTER TABLE tournament_match
    ADD FOREIGN KEY (away_team_id) REFERENCES bridge_team_tournament (team_tournament_sk);

ALTER TABLE tournament_match
    ADD FOREIGN KEY (stadium_id) REFERENCES dim_stadium (stadium_id);

ALTER TABLE match_player_detail
    ADD FOREIGN KEY (player_id) REFERENCES dim_player (player_id);

ALTER TABLE dim_team
    ADD FOREIGN KEY (league_id) REFERENCES dim_league (league_id);
