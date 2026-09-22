select user_id, 
CASE WHEN sum(total_amount) > 500 THEN 'high' WHEN sum(total_amount) >= 200 THEN 'medium' ELSE 'low' END
from transactions
group by 1
