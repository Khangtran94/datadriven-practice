SELECT edge_loc, 
    COUNT(*) AS request_count,
    ROUND(100.0 * SUM(cache_hit) / COUNT(*),2) AS hit_pct,
    ROUND(
        100.0 * SUM(SUM(cache_hit)) OVER ()
        / SUM(COUNT(*)) OVER (),
        2
    ) AS overall_hit_pct
FROM cdn_logs
GROUP BY 1 ORDER BY 3 desc
