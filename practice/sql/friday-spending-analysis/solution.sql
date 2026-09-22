select extract(week from transaction_date), AVG(total_amount)
FROM transactions
WHERE extract(week from transaction_date) <= 12
    AND extract(dow from transaction_date) = 5
GROUP BY 1 
