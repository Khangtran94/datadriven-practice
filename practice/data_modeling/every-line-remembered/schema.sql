CREATE TABLE dim_date (
    date_sk DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_customer (
    customer_sk INT,
    customer_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    city CHAR,
    effective_from DATE,
    effective_to DATE,
    is_active BOOLEAN,
    PRIMARY KEY (customer_sk)
);

CREATE TABLE dim_product (
    product_sk INT,
    product_id INT,
    name CHAR,
    type CHAR,
    effective_from DATE,
    effective_to DATE,
    is_active BOOLEAN,
    price DECIMAL,
    PRIMARY KEY (product_sk)
);

CREATE TABLE dim_employee (
    employee_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    date_joined DATE,
    PRIMARY KEY (employee_id)
);

CREATE TABLE dim_store (
    store_id INT,
    name CHAR,
    address CHAR,
    city CHAR,
    PRIMARY KEY (store_id)
);

CREATE TABLE fact_order (
    order_date DATE,
    order_id INT,
    customer_sk INT,
    store_id INT,
    employee_id INT,
    total_amount DECIMAL,
    PRIMARY KEY (order_id)
);

CREATE TABLE fact_order_line (
    order_line_sk INT,
    order_id INT,
    product_sk INT,
    quantity INT,
    amount DECIMAL,
    PRIMARY KEY (order_line_sk)
);

ALTER TABLE dim_customer
    ADD FOREIGN KEY (effective_from) REFERENCES dim_date (date_sk);

ALTER TABLE dim_customer
    ADD FOREIGN KEY (effective_to) REFERENCES dim_date (date_sk);

ALTER TABLE dim_product
    ADD FOREIGN KEY (effective_to) REFERENCES dim_date (date_sk);

ALTER TABLE dim_product
    ADD FOREIGN KEY (effective_from) REFERENCES dim_date (date_sk);

ALTER TABLE dim_employee
    ADD FOREIGN KEY (date_joined) REFERENCES dim_date (date_sk);

ALTER TABLE fact_order
    ADD FOREIGN KEY (store_id) REFERENCES dim_store (store_id);

ALTER TABLE fact_order
    ADD FOREIGN KEY (order_date) REFERENCES dim_date (date_sk);

ALTER TABLE fact_order_line
    ADD FOREIGN KEY (order_id) REFERENCES fact_order (order_id);

ALTER TABLE fact_order
    ADD FOREIGN KEY (customer_sk) REFERENCES dim_customer (customer_sk);

ALTER TABLE fact_order_line
    ADD FOREIGN KEY (product_sk) REFERENCES dim_product (product_sk);

ALTER TABLE fact_order
    ADD FOREIGN KEY (employee_id) REFERENCES dim_employee (employee_id);
