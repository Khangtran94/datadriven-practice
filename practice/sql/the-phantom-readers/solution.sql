with views AS
(SELECT user_id, COUNT(*) AS total_views
FROM page_views
WHERE viewed_at >= (
    SELECT MAX(viewed_at) - INTERVAL '30 days'
    FROM page_views)
GROUP BY 1
HAVING total_views >= 5),

buy AS
(SELECT user_id, COUNT(*) AS cnt_transaction
FROM transactions
WHERE transaction_date >= (SELECT MAX(transaction_date) - INTERVAL '30 days' FROM transactions)
GROUP BY 1)

SELECT user_id, username, email, total_views
FROM views 
INNER JOIN users
USING (user_id)
WHERE user_id NOT IN (SELECT user_id FROM buy)
ORDER BY 4 desc,2
