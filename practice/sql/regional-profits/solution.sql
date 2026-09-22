select region, sum(profit), count(*)
from orders
where region is not null
GROUP BY 1 
ORDER By 2 desc
