CREATE TABLE dim_consultant (
    consultant_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    PRIMARY KEY (consultant_id)
);

CREATE TABLE dim_client (
    client_id INT,
    name CHAR,
    address CHAR,
    phone CHAR,
    PRIMARY KEY (client_id)
);

CREATE TABLE fact_rate (
    rate_id INT,
    consultant_id INT,
    client_id INT,
    rate_per_hour DECIMAL,
    from_date INT,
    to_date INT,
    is_active BOOLEAN,
    PRIMARY KEY (rate_id)
);

CREATE TABLE dim_date (
    date_sk INT,
    full_date DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE log_billable (
    bill_id INT,
    rate_id INT,
    bill_date INT,
    log_hour DECIMAL,
    PRIMARY KEY (bill_id)
);

CREATE TABLE fact_invoice (
    invoice_id INT,
    bill_id INT,
    invoice_date INT,
    total_amount DECIMAL,
    status CHAR,
    PRIMARY KEY (invoice_id)
);

ALTER TABLE fact_rate
    ADD FOREIGN KEY (client_id) REFERENCES dim_client (client_id);

ALTER TABLE fact_rate
    ADD FOREIGN KEY (consultant_id) REFERENCES dim_consultant (consultant_id);

ALTER TABLE fact_rate
    ADD FOREIGN KEY (from_date) REFERENCES dim_date (date_sk);

ALTER TABLE fact_rate
    ADD FOREIGN KEY (to_date) REFERENCES dim_date (date_sk);

ALTER TABLE log_billable
    ADD FOREIGN KEY (rate_id) REFERENCES fact_rate (rate_id);

ALTER TABLE log_billable
    ADD FOREIGN KEY (bill_date) REFERENCES dim_date (date_sk);

ALTER TABLE fact_invoice
    ADD FOREIGN KEY (bill_id) REFERENCES log_billable (bill_id);

ALTER TABLE fact_invoice
    ADD FOREIGN KEY (invoice_date) REFERENCES dim_date (date_sk);
