SELECT *
from alert_events
where extract(year from fired_at) = 2026
    AND lower(severity) IN ('high','critical')
