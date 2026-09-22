select strftime('%Y-%m', transaction_date),
      SUM(total_amount), 
       COUNT(*),
      SUM(total_amount) / COUNT(*)
FROM transactions
GROUP BY 1 
ORDER by 1
