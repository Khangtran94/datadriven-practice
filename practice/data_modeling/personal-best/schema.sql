CREATE TABLE dim_user (
    user_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    PRIMARY KEY (user_id)
);

CREATE TABLE dim_date (
    date_sk INT,
    day INT,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_exercise (
    exercise_id INT,
    name CHAR,
    PRIMARY KEY (exercise_id)
);

CREATE TABLE fact_log (
    log_id INT,
    user_id INT,
    date_sk INT,
    exercise_id INT,
    sets INT,
    reps INT,
    weight_lifted INT,
    PRIMARY KEY (log_id)
);

ALTER TABLE fact_log
    ADD FOREIGN KEY (user_id) REFERENCES dim_user (user_id);

ALTER TABLE fact_log
    ADD FOREIGN KEY (date_sk) REFERENCES dim_date (date_sk);

ALTER TABLE fact_log
    ADD FOREIGN KEY (exercise_id) REFERENCES dim_exercise (exercise_id);
