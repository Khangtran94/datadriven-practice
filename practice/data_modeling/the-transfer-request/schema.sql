CREATE TABLE dim_date (
    date_sk INT,
    day INT,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_employee (
    employee_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    PRIMARY KEY (employee_id)
);

CREATE TABLE fact_application (
    application_id INT,
    date_sk INT,
    employee_id INT,
    originating_team CHAR,
    destination_team CHAR,
    status CHAR,
    PRIMARY KEY (application_id)
);

ALTER TABLE fact_application
    ADD FOREIGN KEY (date_sk) REFERENCES dim_date (date_sk);

ALTER TABLE fact_application
    ADD FOREIGN KEY (employee_id) REFERENCES dim_employee (employee_id);
