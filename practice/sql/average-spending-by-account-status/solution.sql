SELECT account_status,
      -- SUM(total_amount) AS total_spend,
      -- COUNT(DISTINCT user_id) AS unique_user,
      ROUND(SUM(total_amount) / COUNT(DISTINCT user_id),3) AS avg_total_spending
FROM transactions
INNER JOIN users 
USING (user_id)
GROUP BY 1
