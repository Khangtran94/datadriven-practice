CREATE TABLE dim_user (
    user_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    PRIMARY KEY (user_id)
);

CREATE TABLE dim_creator (
    creator_id INT,
    name CHAR,
    phone CHAR,
    email CHAR,
    PRIMARY KEY (creator_id)
);

CREATE TABLE dim_date (
    date_sk INT,
    full_date DATE,
    month INT,
    year INT,
    PRIMARY KEY (date_sk)
);

CREATE TABLE bridge_follow (
    follow_date INT,
    create_id INT,
    user_id INT,
    PRIMARY KEY (follow_date, create_id, user_id)
);

CREATE TABLE dim_post (
    post_id INT,
    creator_id INT,
    post_type CHAR,
    content CHAR,
    PRIMARY KEY (post_id)
);

CREATE TABLE like_post (
    like_id INT,
    user_id INT,
    post_id INT,
    like_time TIMESTAMP,
    PRIMARY KEY (like_id, user_id, post_id)
);

CREATE TABLE comment_table (
    comment_id INT,
    user_id INT,
    post_id INT,
    content CHAR,
    comment_time TIMESTAMP,
    PRIMARY KEY (comment_id)
);

CREATE TABLE reply_table (
    reply_id INT,
    reply_from_comment_id INT,
    user_id INT,
    content CHAR,
    reply_time TIMESTAMP,
    PRIMARY KEY (reply_id)
);

ALTER TABLE bridge_follow
    ADD FOREIGN KEY (user_id) REFERENCES dim_user (user_id);

ALTER TABLE bridge_follow
    ADD FOREIGN KEY (create_id) REFERENCES dim_creator (creator_id);

ALTER TABLE bridge_follow
    ADD FOREIGN KEY (follow_date) REFERENCES dim_date (date_sk);

ALTER TABLE dim_post
    ADD FOREIGN KEY (creator_id) REFERENCES dim_creator (creator_id);

ALTER TABLE like_post
    ADD FOREIGN KEY (post_id) REFERENCES dim_post (post_id);

ALTER TABLE like_post
    ADD FOREIGN KEY (user_id) REFERENCES dim_user (user_id);

ALTER TABLE comment_table
    ADD FOREIGN KEY (post_id) REFERENCES dim_post (post_id);

ALTER TABLE comment_table
    ADD FOREIGN KEY (user_id) REFERENCES dim_user (user_id);

ALTER TABLE reply_table
    ADD FOREIGN KEY (reply_from_comment_id) REFERENCES comment_table (comment_id);

ALTER TABLE reply_table
    ADD FOREIGN KEY (user_id) REFERENCES dim_user (user_id);
