CREATE TABLE dim_date (
    date_sk DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE dim_truck (
    truck_id INT,
    license_plate INT,
    PRIMARY KEY (truck_id)
);

CREATE TABLE dim_food (
    menu_food_id INT,
    menu_id INT,
    food_name CHAR,
    price DECIMAL,
    PRIMARY KEY (menu_food_id)
);

CREATE TABLE food_order (
    order_id INT,
    order_date DATE,
    location_id INT,
    truck_id INT,
    total_revenue DECIMAL,
    status CHAR,
    PRIMARY KEY (order_id)
);

CREATE TABLE dim_location (
    location_id INT,
    street CHAR,
    city CHAR,
    PRIMARY KEY (location_id)
);

CREATE TABLE dim_menu (
    menu_id INT,
    menu_name CHAR,
    PRIMARY KEY (menu_id)
);

CREATE TABLE order_detail (
    order_line_id INT,
    menu_food_id INT,
    order_id INT,
    quantity INT,
    amount DECIMAL,
    PRIMARY KEY (order_line_id)
);

ALTER TABLE food_order
    ADD FOREIGN KEY (order_date) REFERENCES dim_date (date_sk);

ALTER TABLE food_order
    ADD FOREIGN KEY (location_id) REFERENCES dim_location (location_id);

ALTER TABLE food_order
    ADD FOREIGN KEY (truck_id) REFERENCES dim_truck (truck_id);

ALTER TABLE order_detail
    ADD FOREIGN KEY (order_id) REFERENCES food_order (order_id);

ALTER TABLE dim_food
    ADD FOREIGN KEY (menu_id) REFERENCES dim_menu (menu_id);

ALTER TABLE order_detail
    ADD FOREIGN KEY (menu_food_id) REFERENCES dim_food (menu_food_id);
