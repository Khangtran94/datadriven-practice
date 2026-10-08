CREATE TABLE dim_customer (
    customer_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    PRIMARY KEY (customer_id)
);

CREATE TABLE fact_application (
    application_id INT,
    customer_sk INT,
    loan_amount DECIMAL,
    date_applied DATE,
    status CHAR,
    PRIMARY KEY (application_id)
);

CREATE TABLE dim_segment (
    segment_id INT,
    credit_score INT,
    segment_name CHAR,
    PRIMARY KEY (segment_id)
);

CREATE TABLE customer_segment (
    customer_sk INT,
    customer_id INT,
    segment_id INT,
    from_date DATE,
    to_date DATE,
    is_active BOOLEAN,
    PRIMARY KEY (customer_sk)
);

CREATE TABLE offer_application (
    offer_id INT,
    application_id INT,
    date_offer DATE,
    offer_amount DECIMAL,
    status CHAR,
    PRIMARY KEY (offer_id)
);

CREATE TABLE loan_offer (
    loan_id INT,
    offer_id INT,
    date_loan DATE,
    loan_approved DECIMAL,
    PRIMARY KEY (loan_id)
);

ALTER TABLE customer_segment
    ADD FOREIGN KEY (customer_id) REFERENCES dim_customer (customer_id);

ALTER TABLE customer_segment
    ADD FOREIGN KEY (segment_id) REFERENCES dim_segment (segment_id);

ALTER TABLE fact_application
    ADD FOREIGN KEY (customer_sk) REFERENCES customer_segment (customer_sk);

ALTER TABLE offer_application
    ADD FOREIGN KEY (application_id) REFERENCES fact_application (application_id);

ALTER TABLE loan_offer
    ADD FOREIGN KEY (offer_id) REFERENCES offer_application (offer_id);
