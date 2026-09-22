SELECT svc_name, MAX(count)
FROM err_tracks
WHERE extract(year from first_at) = 2026
GROUP BY 1 order by 2 desc
