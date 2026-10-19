CREATE TABLE dim_user (
    user_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    PRIMARY KEY (user_id)
);

CREATE TABLE dim_date (
    date_sk INT,
    full_date DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_experiment (
    experiment_id INT,
    name CHAR,
    PRIMARY KEY (experiment_id)
);

CREATE TABLE assignment (
    experiment_id INT,
    user_id INT,
    variant CHAR,
    enrolled_at TIMESTAMP,
    is_control BOOLEAN,
    PRIMARY KEY (experiment_id, user_id)
);

CREATE TABLE event_log (
    event_id INT,
    user_id INT,
    event_type CHAR,
    event_time TIMESTAMP,
    PRIMARY KEY (event_id)
);

ALTER TABLE assignment
    ADD FOREIGN KEY (experiment_id) REFERENCES dim_experiment (experiment_id);

ALTER TABLE assignment
    ADD FOREIGN KEY (user_id) REFERENCES dim_user (user_id);

ALTER TABLE event_log
    ADD FOREIGN KEY (user_id) REFERENCES dim_user (user_id);
