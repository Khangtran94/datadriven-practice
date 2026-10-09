CREATE TABLE dim_customer (
    customer_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    PRIMARY KEY (customer_id)
);

CREATE TABLE dim_date (
    date_sk INT,
    day INT,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE fact_application (
    application_id INT,
    customer_id INT,
    date_sk INT,
    loan_type CHAR,
    loan_amount BIGINT,
    interest_rate DECIMAL,
    term_length INT,
    PRIMARY KEY (application_id)
);

CREATE TABLE payment (
    payment_id INT,
    application_id INT,
    amount_paid BIGINT,
    status CHAR,
    paid_date DATE,
    PRIMARY KEY (payment_id)
);

ALTER TABLE fact_application
    ADD FOREIGN KEY (customer_id) REFERENCES dim_customer (customer_id);

ALTER TABLE fact_application
    ADD FOREIGN KEY (date_sk) REFERENCES dim_date (date_sk);

ALTER TABLE payment
    ADD FOREIGN KEY (application_id) REFERENCES fact_application (application_id);
