SELECT extract(dow from call_time) As day_of_week,
      CASE WHEN extract(hour from call_time) < 12 THEN 'Morning'
          WHEN extract(hour from call_time) < 15 THEN 'Early Afternoon'
          else 'Late Afternoon' END AS time_segment, 
      COUNT(*) AS call_count
FROM api_calls
WHERE call_time is not null
GROUP BY 1,2 
QUALIFY DENSE_RANK() OVER(ORDER BY call_count DESC) <= 2
ORDER BY 3 desc
