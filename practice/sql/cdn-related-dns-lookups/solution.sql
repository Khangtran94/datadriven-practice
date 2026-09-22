SELECT * 
FROM dns_lookups
WHERE LOWER(domain) LIKE '%cdn%'
