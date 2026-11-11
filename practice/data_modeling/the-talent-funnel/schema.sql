CREATE TABLE dim_date (
    date_sk INT,
    full_date DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_candidate (
    candidate_id INT,
    date_of_birth INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    country CHAR,
    PRIMARY KEY (candidate_id)
);

CREATE TABLE dim_job (
    job_id INT,
    date_listed_job INT,
    date_expired_job INT,
    job_title CHAR,
    company_name CHAR,
    job_type CHAR,
    location CHAR,
    PRIMARY KEY (job_id)
);

CREATE TABLE fact_application_lifecycle (
    application_id INT,
    job_id INT,
    candidate_id INT,
    date_view INT,
    date_apply_resume INT,
    date_interview INT,
    date_offer INT,
    channel_reach_id INT,
    current_status CHAR,
    PRIMARY KEY (application_id)
);

CREATE TABLE dim_channel (
    channel_id INT,
    channel_name CHAR,
    channel_type CHAR,
    PRIMARY KEY (channel_id)
);

ALTER TABLE dim_candidate
    ADD FOREIGN KEY (date_of_birth) REFERENCES dim_date (date_sk);

ALTER TABLE dim_job
    ADD FOREIGN KEY (date_listed_job) REFERENCES dim_date (date_sk);

ALTER TABLE dim_job
    ADD FOREIGN KEY (date_expired_job) REFERENCES dim_date (date_sk);

ALTER TABLE fact_application_lifecycle
    ADD FOREIGN KEY (job_id) REFERENCES dim_job (job_id);

ALTER TABLE fact_application_lifecycle
    ADD FOREIGN KEY (candidate_id) REFERENCES dim_candidate (candidate_id);

ALTER TABLE fact_application_lifecycle
    ADD FOREIGN KEY (date_view) REFERENCES dim_date (date_sk);

ALTER TABLE fact_application_lifecycle
    ADD FOREIGN KEY (date_apply_resume) REFERENCES dim_date (date_sk);

ALTER TABLE fact_application_lifecycle
    ADD FOREIGN KEY (date_interview) REFERENCES dim_date (date_sk);

ALTER TABLE fact_application_lifecycle
    ADD FOREIGN KEY (date_offer) REFERENCES dim_date (date_sk);

ALTER TABLE fact_application_lifecycle
    ADD FOREIGN KEY (channel_reach_id) REFERENCES dim_channel (channel_id);
