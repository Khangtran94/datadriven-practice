with all_money AS
(SELECT 
      user_id, 
      SUM(total_amount) AS total
FROM transactions
GROUP BY 1 
ORDER BY 2 DESC)

SELECT user_id,   
      total, 
      ROUND(total - (SELECT AVG(total) FROM all_money),2) AS above_avg
FROM all_money
WHERE above_avg > 0
