select extract(dow from event_timestamp), count(*)
from event_data
where extract(dow from event_timestamp) IN (1,6)
group by 1
