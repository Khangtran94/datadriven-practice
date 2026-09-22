SELECT status,COUNT(*), AVG(profit)
FROm orders
WHERE status IS NOT null
GROUP BY 1
HAVING COUNT(*) >= 5
ORDER BY 2 desc
