select distinct err_type
FROM err_tracks
GROUP BY 1
HAVING COUNT(*) > 1
