SELECT endpoint, COUNT(*) AS successful_calls
FROM api_calls
where status = 200
GROUP BY 1 
order by 2 desc
