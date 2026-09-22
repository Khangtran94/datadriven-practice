with total AS
(SELECT lower(device) AS device, 
      SUM(dur_ms) AS total_dwell_ms
FROM page_views
GROUP BY 1 order by 2 desc)

SELECT *, 
      ROUND(100.0 * SUM(total_dwell_ms) OVER(ORDER BY total_dwell_ms DESC) / SUM(total_dwell_ms) OVER(),2) AS running_pct 
FROM total
