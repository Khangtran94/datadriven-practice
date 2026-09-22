SELECT user_id, SUM(total_amount), COUNT(*), ROUND(AVG(total_amount),2)
FROM transactions
GROUP BY 1 HAVING SUM(total_amount) > 5000
ORDER BY 2 desc
