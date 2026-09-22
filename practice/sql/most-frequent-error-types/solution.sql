SELECT err_type, COUNT(*)
FROM err_tracks
GROUP BY 1 
ORDER BY 2 desc
