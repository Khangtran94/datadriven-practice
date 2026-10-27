CREATE TABLE customer (
    customer_sk INT,
    customer_id INT,
    name CHAR,
    address CHAR,
    membership_tier CHAR,
    email CHAR,
    from_date INT,
    to_date INT,
    is_active BOOLEAN,
    PRIMARY KEY (customer_sk)
);

CREATE TABLE fact_order (
    order_id INT,
    order_date INT,
    customer_sk INT,
    quantity INT,
    amount DECIMAL,
    PRIMARY KEY (order_id)
);

CREATE TABLE dim_date (
    date_sk INT,
    full_date DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

ALTER TABLE fact_order
    ADD FOREIGN KEY (order_date) REFERENCES dim_date (date_sk);

ALTER TABLE fact_order
    ADD FOREIGN KEY (customer_sk) REFERENCES customer (customer_sk);

ALTER TABLE customer
    ADD FOREIGN KEY (from_date) REFERENCES dim_date (date_sk);

ALTER TABLE customer
    ADD FOREIGN KEY (to_date) REFERENCES dim_date (date_sk);
