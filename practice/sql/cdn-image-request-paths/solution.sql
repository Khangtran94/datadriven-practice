SELECT edge_loc, req_path 
FROM cdn_logs
WHERE req_path ILIKE '%image%'
