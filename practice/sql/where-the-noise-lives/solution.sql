SELECT CASE WHEN EXTRACT(dow FROM log_timestamp) = 0 THEN 'Sunday'
            WHEN EXTRACT(dow FROM log_timestamp) = 1 THEN 'Monday'
            WHEN EXTRACT(dow FROM log_timestamp) = 2 THEN 'Tuesday'
            WHEN EXTRACT(dow FROM log_timestamp) = 3 THEN 'Wednesday'
            WHEN EXTRACT(dow FROM log_timestamp) = 4 THEN 'Thursday'
            WHEN EXTRACT(dow FROM log_timestamp) = 5 THEN 'Friday'
            ELSE 'Saturday' END AS day_of_week,
            COUNT(*) AS entry_count
FROM server_logs
GROUP BY EXTRACT(dow FROM log_timestamp)
