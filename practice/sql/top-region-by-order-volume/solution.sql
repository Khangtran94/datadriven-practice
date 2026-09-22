SELECT region, count(*)
from orders
group by 1 order by 2 desc limit 1
