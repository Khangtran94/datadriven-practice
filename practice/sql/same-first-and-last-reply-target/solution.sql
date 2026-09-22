with combine AS
(SELECT channel, 
      STRFTIME('%Y-%m',sent_at) AS msg_month,
      reply_to, 
      sent_at,
      ROW_NUMBER() OVER(PARTITION BY channel, STRFTIME('%Y-%m',sent_at) ORDER BY sent_at) AS rnk_mess,
      ROW_NUMBER() OVER(PARTITION BY channel, STRFTIME('%Y-%m',sent_at) ORDER BY sent_at DESC) AS rnk_desc
FROM chat_msgs
WHERE reply_to IS NOT NULL
ORDER BY channel, msg_month)

SELECT channel, msg_month,
      MAX(CASE WHEN rnk_mess = 1 THEN reply_to END) AS first_recipient,
      MAX(CASE WHEN rnk_desc = 1 THEN reply_to END) AS last_recipient
FROM combine
GROUP BY channel, msg_month
ORDER BY channel, msg_month
