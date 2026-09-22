SElECT user_id, SUM(total_amount) AS total_spend
FROM transactions
WHERE transaction_date >= DATE('now','-30 days')
    AND transaction_date <= DATE('now')
GROUP BY 1 
HAVING total_spend > 0 
order by 2 desc
