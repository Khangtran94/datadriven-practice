select distinct user_id
from event_data where event_type = 'purchase' 
      and user_id IN (select user_id from users)
