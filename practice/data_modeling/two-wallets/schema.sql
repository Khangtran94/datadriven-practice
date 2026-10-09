CREATE TABLE dim_user (
    user_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    user_type CHAR,
    PRIMARY KEY (user_id)
);

CREATE TABLE payment (
    payment_id INT,
    user_id CHAR,
    token CHAR,
    payment_method CHAR,
    last_four_digits CHAR,
    plan_tier CHAR,
    subscribed_started DATE,
    subscribed_ended DATE,
    PRIMARY KEY (payment_id)
);

ALTER TABLE payment
    ADD FOREIGN KEY (user_id) REFERENCES dim_user (user_id);
