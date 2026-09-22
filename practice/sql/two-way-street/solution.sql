with total AS
(SELECT sender_id, reply_to,
    CASE WHEN sender_id < reply_to THEN CONCAT(sender_id,'_',reply_to)
        ELSE CONCAT(reply_to,'_',sender_id) END AS pair
FROM chat_msgs
WHERE reply_to IS NOT NULL)

SELECT COUNT(distinct pair)
FROM total
