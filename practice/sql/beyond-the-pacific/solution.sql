select svc_name, max(amount) As max_amount
from cloud_costs
where region not like 'ap%' 
    AND upper(provider) IN ('GCP','AWS')
GROUP BY svc_name
HAVING COUNT(*) >= 20
