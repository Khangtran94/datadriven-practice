WITH member_activity AS (
  SELECT
    user_id,
    COUNT(*) AS txn_count
  FROM transactions
  GROUP BY user_id
)
SELECT
  ROUND(
    100 * SUM(
      CASE
        WHEN txn_count >= 2 THEN 1
        ELSE 0
      END
      ) / COUNT(*),
    2
    ) AS repeat_member_pct
FROM member_activity
