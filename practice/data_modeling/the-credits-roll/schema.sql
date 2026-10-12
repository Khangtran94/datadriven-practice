CREATE TABLE dim_film (
    film_id INT,
    title CHAR,
    released_year INT,
    genre CHAR,
    PRIMARY KEY (film_id)
);

CREATE TABLE dim_person (
    person_id INT,
    name CHAR,
    dob DATE,
    country CHAR,
    PRIMARY KEY (person_id)
);

CREATE TABLE bridge_film_credit (
    credit_id INT,
    film_id INT,
    person_id INT,
    order_id INT,
    production_role CHAR,
    character_name CHAR,
    billing_order INT,
    PRIMARY KEY (credit_id, film_id, person_id, order_id)
);

CREATE TABLE dim_order (
    order_id INT,
    amount DECIMAL,
    order_date DATE,
    PRIMARY KEY (order_id)
);

ALTER TABLE bridge_film_credit
    ADD FOREIGN KEY (film_id) REFERENCES dim_film (film_id);

ALTER TABLE bridge_film_credit
    ADD FOREIGN KEY (person_id) REFERENCES dim_person (person_id);

ALTER TABLE bridge_film_credit
    ADD FOREIGN KEY (order_id) REFERENCES dim_order (order_id);
