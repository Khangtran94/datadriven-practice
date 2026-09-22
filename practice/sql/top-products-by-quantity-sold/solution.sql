SELECT product_id, SUM(quantity)
FROM transactions
WHERE extract(year from transaction_date) = 2026
GROUP BY 1 order by 2 desc
