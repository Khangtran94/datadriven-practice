SELECT region, sum(profit)
FROM orders
WHERE status != 'Cancelled'
GROUP BY 1
ORDER BY 2 DESC
