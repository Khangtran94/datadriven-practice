SELECT
    sender_id AS user_a,
    reply_to AS user_b
FROM chat_msgs
WHERE reply_to IS NOT NULL

UNION

SELECT
    reply_to AS user_a,
    sender_id AS user_b
FROM chat_msgs
WHERE reply_to IS NOT NULL

ORDER BY user_a;
