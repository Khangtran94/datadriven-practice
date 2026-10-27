CREATE TABLE dim_product (
    product_id INT,
    name CHAR,
    is_active BOOLEAN,
    date_listed DATE,
    effective_from DATE,
    effective_to DATE,
    PRIMARY KEY (product_id)
);

CREATE TABLE dim_seller (
    seller_id INT,
    name CHAR,
    PRIMARY KEY (seller_id)
);

CREATE TABLE fact_event (
    event_id INT,
    product_id INT,
    seller_id INT,
    event_date INT,
    action CHAR,
    units_sold INT,
    revenue INT,
    PRIMARY KEY (event_id)
);

CREATE TABLE daily_dashboard (
    seller_id INT,
    date INT,
    active_count INT,
    daily_revenue INT,
    daily_unit_sales INT,
    PRIMARY KEY (seller_id, date)
);

CREATE TABLE dim_date (
    date_id INT,
    day INT,
    month INT,
    year INT,
    PRIMARY KEY (date_id)
);

ALTER TABLE fact_event
    ADD FOREIGN KEY (product_id) REFERENCES dim_product (product_id);

ALTER TABLE fact_event
    ADD FOREIGN KEY (seller_id) REFERENCES dim_seller (seller_id);

ALTER TABLE daily_dashboard
    ADD FOREIGN KEY (seller_id) REFERENCES dim_seller (seller_id);

ALTER TABLE daily_dashboard
    ADD FOREIGN KEY (date) REFERENCES dim_date (date_id);
