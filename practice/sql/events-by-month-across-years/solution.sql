SELECT EXTRACT(month from event_timestamp) AS month,
      COUNT(*) AS event_count
FROM event_data
GROUP BY month
