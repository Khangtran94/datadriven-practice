select pipe_name, COUNT(*)
FROM data_pipes
WHERE status = 'success'
GROUP BY 1 
order by 2 desc
