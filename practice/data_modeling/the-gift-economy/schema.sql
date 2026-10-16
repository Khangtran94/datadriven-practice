CREATE TABLE dim_creator (
    creator_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    PRIMARY KEY (creator_id)
);

CREATE TABLE dim_viewer (
    viewer_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    PRIMARY KEY (viewer_id)
);

CREATE TABLE chat_message (
    chat_id INT,
    session_id INT,
    message_time TIMESTAMP,
    message VARCHAR,
    PRIMARY KEY (chat_id)
);

CREATE TABLE stream (
    stream_id INT,
    date_stream INT,
    category_id INT,
    creator_id INT,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    PRIMARY KEY (stream_id)
);

CREATE TABLE viewer_session (
    session_id INT,
    stream_id INT,
    viewer_id INT,
    join_time TIMESTAMP,
    leave_time TIMESTAMP,
    PRIMARY KEY (session_id)
);

CREATE TABLE gift (
    gift_event INT,
    session_id INT,
    dollar_amount FLOAT,
    send_time TIMESTAMP,
    gift_name VARCHAR,
    gift_purchase CHAR,
    PRIMARY KEY (gift_event)
);

CREATE TABLE stream_category (
    category_id INT,
    genre CHAR,
    name CHAR,
    PRIMARY KEY (category_id)
);

CREATE TABLE dim_date (
    date_sk INT,
    full_date DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

ALTER TABLE viewer_session
    ADD FOREIGN KEY (stream_id) REFERENCES stream (stream_id);

ALTER TABLE stream
    ADD FOREIGN KEY (date_stream) REFERENCES dim_date (date_sk);

ALTER TABLE viewer_session
    ADD FOREIGN KEY (viewer_id) REFERENCES dim_viewer (viewer_id);

ALTER TABLE chat_message
    ADD FOREIGN KEY (session_id) REFERENCES viewer_session (session_id);

ALTER TABLE stream
    ADD FOREIGN KEY (creator_id) REFERENCES dim_creator (creator_id);

ALTER TABLE stream
    ADD FOREIGN KEY (category_id) REFERENCES stream_category (category_id);

ALTER TABLE gift
    ADD FOREIGN KEY (session_id) REFERENCES viewer_session (session_id);
