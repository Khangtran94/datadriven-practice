select edge_loc, req_path, SUM(bytes) as total_bytes
FROM cdn_logs
WHERE edge_loc IN (SELECT distinct edge_loc
FROM cdn_logs
where cache_hit = 1 and req_path LIKE '%api%')
  AND req_path LIKE '%api%'
GROUP BY 1,2
ORDER BY 3
