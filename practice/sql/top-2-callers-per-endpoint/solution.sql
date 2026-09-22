with each AS
(SELECT endpoint, user_id, COUNT(*) as cnt
FROM api_calls
GROUP BY 1,2)

SELECT endpoint, user_id, DENSE_RANK() OVER(PARTITION BY endpoint ORDER BY cnt DESC) AS rnk
FROM each
QUALIFY rnk <= 2
