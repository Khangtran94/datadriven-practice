SELECT DATE(first_at) AS error_date,
    COUNT(*) AS error_count,
    LAG(COUNT(*)) OVER(ORDER BY DATE(first_at)) AS prev_count,
    COUNT(*) - LAG(COUNT(*)) OVER(ORDER BY DATE(first_at)) AS day_over_day_change
FROM err_tracks
GROUP BY DATE(first_at)
ORDER BY DATE(first_at)
