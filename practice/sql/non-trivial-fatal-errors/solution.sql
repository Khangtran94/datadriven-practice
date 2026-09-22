SELECT err_id, message,svc_name,
    CASE WHEN Length(message) BETWEEN 25 AND 35 THEN 'mid'
        WHEN Length(message) > 35 THEN 'long' ELSE 'short' END AS length_category
FROM err_tracks
WHERE lower(severity) = 'fatal'
AND length_category != 'short'
