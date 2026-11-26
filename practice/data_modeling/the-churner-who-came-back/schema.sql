CREATE TABLE dim_date (
    date_sk INT,
    full_date DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_subscriber (
    subscriber_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    region CHAR,
    PRIMARY KEY (subscriber_id)
);

CREATE TABLE dim_plan_tier (
    plan_tier_id INT,
    plan_tier_name CHAR,
    PRIMARY KEY (plan_tier_id)
);

CREATE TABLE subscriber_key (
    subscriber_sk INT,
    date_applied INT,
    subscriber_id INT,
    plan_tier_id INT,
    status CHAR,
    is_active BOOLEAN,
    PRIMARY KEY (subscriber_sk)
);

CREATE TABLE fact_monthly_invoice (
    invoice_id INT,
    invoice_date INT,
    subscriber_sk INT,
    month INT,
    revenue DECIMAL,
    PRIMARY KEY (invoice_id)
);

ALTER TABLE subscriber_key
    ADD FOREIGN KEY (date_applied) REFERENCES dim_date (date_sk);

ALTER TABLE subscriber_key
    ADD FOREIGN KEY (plan_tier_id) REFERENCES dim_plan_tier (plan_tier_id);

ALTER TABLE subscriber_key
    ADD FOREIGN KEY (subscriber_id) REFERENCES dim_subscriber (subscriber_id);

ALTER TABLE fact_monthly_invoice
    ADD FOREIGN KEY (subscriber_sk) REFERENCES subscriber_key (subscriber_sk);

ALTER TABLE fact_monthly_invoice
    ADD FOREIGN KEY (invoice_date) REFERENCES dim_date (date_sk);
