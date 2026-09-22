SELECT *
FROM migrations
WHERE status = 'Applied'
ORDER BY migr_id DESC
lIMIT 1
