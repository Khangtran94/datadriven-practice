select svc_name, 
    SUM(count) FILTER(WHERE EXISTS(SELECT 1 FROM alert_events WHERE alert_events.svc_name = err_tracks.svc_name)) AS total_errors
FROM err_tracks
GROUP BY 1 
HAVING total_errors is not null
order by 2 desc
