CREATE TABLE dim_date (
    date_sk INT,
    full_date DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE claim_lifecycle (
    claim_id INT,
    customer_sk INT,
    filed_date INT,
    amount DECIMAL,
    status CHAR,
    PRIMARY KEY (claim_id)
);

CREATE TABLE dim_customer (
    customer_sk INT,
    customer_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    address CHAR,
    city CHAR,
    effective_from DATE,
    effective_to DATE,
    is_current BOOLEAN,
    PRIMARY KEY (customer_sk)
);

CREATE TABLE version_log (
    log_id INT,
    claim_id INT,
    date_updated INT,
    updated_status CHAR,
    PRIMARY KEY (log_id)
);

ALTER TABLE claim_lifecycle
    ADD FOREIGN KEY (customer_sk) REFERENCES dim_customer (customer_sk);

ALTER TABLE claim_lifecycle
    ADD FOREIGN KEY (filed_date) REFERENCES dim_date (date_sk);

ALTER TABLE version_log
    ADD FOREIGN KEY (claim_id) REFERENCES claim_lifecycle (claim_id);

ALTER TABLE version_log
    ADD FOREIGN KEY (date_updated) REFERENCES dim_date (date_sk);
