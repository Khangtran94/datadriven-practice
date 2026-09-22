SELECT *
FROM err_tracks
WHERE svc_name LIKE '%gateway%' AND message LIKE '%timed out%'
