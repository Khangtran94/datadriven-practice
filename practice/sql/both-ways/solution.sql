SELECT transaction_date, SUM(total_amount) AS net_revenue
FROm transactions
WHERE transaction_date BETWEEN '2026-01-01' AND '2026-04-30'
GROUP BY 1 
ORDER BY 1
