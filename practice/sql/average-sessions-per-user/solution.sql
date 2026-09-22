with total AS
(SELECT user_id, COUNT(*) AS sum_dur
FROM user_sessions
GROUP BY 1)

SELECT AVG(sum_dur)
FROM total
