SELECT region, status, COUNT(*)
FROM orders
where region is not null and status is not null
GROUP BY 1,2
HAVING count(*) >= 3
ORDER By 3 desc
