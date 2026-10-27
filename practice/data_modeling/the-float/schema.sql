CREATE TABLE dim_date (
    date_sk DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_customer (
    customer_id INT,
    signup_at DATE,
    name CHAR,
    phone CHAR,
    email CHAR,
    PRIMARY KEY (customer_id)
);

CREATE TABLE dim_account (
    account_id INT,
    date_registered DATE,
    due_date DATE,
    customer_id INT,
    card_number CHAR,
    initial_amount DECIMAL,
    PRIMARY KEY (account_id)
);

CREATE TABLE fact_hold (
    hold_id INT,
    event_date DATE,
    account_id INT,
    host_time TIMESTAMP,
    hold_amount DECIMAL,
    status CHAR,
    PRIMARY KEY (hold_id)
);

CREATE TABLE tracking_dispute (
    track_id INT,
    dispute_date DATE,
    charged_id INT,
    dispute_type CHAR,
    PRIMARY KEY (track_id)
);

CREATE TABLE fact_charged (
    charged_id INT,
    hold_id INT,
    charged_date DATE,
    charged_time TIMESTAMP,
    charged_amount DECIMAL,
    PRIMARY KEY (charged_id)
);

ALTER TABLE dim_customer
    ADD FOREIGN KEY (signup_at) REFERENCES dim_date (date_sk);

ALTER TABLE dim_account
    ADD FOREIGN KEY (customer_id) REFERENCES dim_customer (customer_id);

ALTER TABLE dim_account
    ADD FOREIGN KEY (due_date) REFERENCES dim_date (date_sk);

ALTER TABLE dim_account
    ADD FOREIGN KEY (date_registered) REFERENCES dim_date (date_sk);

ALTER TABLE fact_hold
    ADD FOREIGN KEY (event_date) REFERENCES dim_date (date_sk);

ALTER TABLE tracking_dispute
    ADD FOREIGN KEY (dispute_date) REFERENCES dim_date (date_sk);

ALTER TABLE fact_hold
    ADD FOREIGN KEY (account_id) REFERENCES dim_account (account_id);

ALTER TABLE fact_charged
    ADD FOREIGN KEY (hold_id) REFERENCES fact_hold (hold_id);

ALTER TABLE tracking_dispute
    ADD FOREIGN KEY (charged_id) REFERENCES fact_charged (charged_id);

ALTER TABLE fact_charged
    ADD FOREIGN KEY (charged_date) REFERENCES dim_date (date_sk);
