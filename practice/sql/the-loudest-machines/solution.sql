SELECT server_name, COUNT(*)
FROm server_logs
WHERE extract(year from log_timestamp) = '2026'
GrouP BY 1
order by 2 desc
