SELECT 
    CASE WHEN (session_duration_sec / 60) < 1 THEN 'under_1min'
          WHEN (session_duration_sec / 60) < 5 THEN '1_to_5min'
          WHEN (session_duration_sec / 60) < 15 THEN '5_to_15min'
          WHEN (session_duration_sec / 60) < 30 THEN '15_to_30min'
          ELSE 'over_30min' END AS duration_bucket,
    COUNT(*) AS session_count,
    ROUND(AVG(pages_viewed),3) AS avg_page
 FROM user_sessions
 GROUP BY 1
order by 3 desc
