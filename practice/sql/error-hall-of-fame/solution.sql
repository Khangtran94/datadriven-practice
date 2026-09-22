SELECT lower(err_type), SUM(count)
FROM err_tracks
GROUP BY 1 order by 2 desc
