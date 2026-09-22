with total AS
(SELECT endpoint, latency, row_number() OVER(partition by user_id order by call_time) as rnk
from api_calls
QUALIFY rnk > 1)

SELECT endpoint, avg(latency)
FROM total
group by 1 order by 2 desc
