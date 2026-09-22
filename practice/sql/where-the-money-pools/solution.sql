select svc_name, SUM(amount)
from cloud_costs
WHERE region = 'us-west-2'
GROUP BY 1 order by 2 desc
