SELECT event_type, 
      COUNT(*) FILTER(WHERE EXTRACT(dow FROM event_timestamp) IN (0,6)) AS weekend_count,
      COUNT(*) FILTER(WHERE EXTRACT(dow FROM event_timestamp) NOT IN (0,6)) AS weekday_count
FROM event_data
GROUP BY 1 
ORDER BY 2 desc, event_type
