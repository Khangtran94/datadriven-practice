CREATE TABLE dim_employee (
    employee_id INT,
    name VARCHAR,
    PRIMARY KEY (employee_id)
);

CREATE TABLE dim_application (
    application_id INT,
    name VARCHAR,
    PRIMARY KEY (application_id)
);

CREATE TABLE daily_app_sessions (
    date_sk INT,
    employee_id INT,
    application_id INT,
    duration INT,
    start_ts TIMESTAMP,
    end_ts TIMESTAMP,
    session_incomplete BOOLEAN,
    flag_overdue BOOLEAN,
    PRIMARY KEY (date_sk, employee_id, application_id)
);

CREATE TABLE dim_date (
    date_sk INT,
    full_date DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

ALTER TABLE daily_app_sessions
    ADD FOREIGN KEY (employee_id) REFERENCES dim_employee (employee_id);

ALTER TABLE daily_app_sessions
    ADD FOREIGN KEY (date_sk) REFERENCES dim_date (date_sk);

ALTER TABLE daily_app_sessions
    ADD FOREIGN KEY (application_id) REFERENCES dim_application (application_id);
