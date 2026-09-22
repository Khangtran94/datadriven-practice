with total AS
(SELECT CASE WHEN email IS NOT NULL then 'has email' ELSE 'no email' END AS email_status FROM users)

SELECT *, COUNT(*) AS user_count,
      100.0 * COUNT(*) / (SELECT COUNT(*) FROM total)
FROM total
GROUP BY 1
