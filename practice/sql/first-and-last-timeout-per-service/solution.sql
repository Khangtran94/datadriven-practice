select svc_name, MIN(first_at), max(first_at)
FROm err_tracks
WHERe message LIKE '%timed out%'
GROUP BY 1 
ORDER BY 1 
