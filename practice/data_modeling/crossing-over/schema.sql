CREATE TABLE dim_date (
    date_sk INT,
    full_date DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_patient (
    patient_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    PRIMARY KEY (patient_id)
);

CREATE TABLE fact_adverse_event (
    event_id INT,
    event_date INT,
    patient_id INT,
    adverse_type CHAR,
    PRIMARY KEY (event_id)
);

CREATE TABLE patient_arm (
    arm_id INT,
    treatment_date INT,
    patient_id INT,
    dose DECIMAL,
    PRIMARY KEY (arm_id)
);

ALTER TABLE fact_adverse_event
    ADD FOREIGN KEY (event_date) REFERENCES dim_date (date_sk);

ALTER TABLE fact_adverse_event
    ADD FOREIGN KEY (patient_id) REFERENCES dim_patient (patient_id);

ALTER TABLE patient_arm
    ADD FOREIGN KEY (treatment_date) REFERENCES dim_date (date_sk);

ALTER TABLE patient_arm
    ADD FOREIGN KEY (patient_id) REFERENCES dim_patient (patient_id);
