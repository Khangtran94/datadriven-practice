select region, count(*), sum(profit)
FROM orders
where region is not null
GROUP by 1 
HAVING COUNT(*) >= 5
order by 3 desc
