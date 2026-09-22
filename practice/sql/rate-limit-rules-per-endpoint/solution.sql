SELECT endpoint, MIN(allowed), MAX(allowed),
    CONCAT('Allowed > ',MIN(allowed),' AND Allowed <= ',MAX(allowed),' => Endpoint = ',endpoint) AS summary
FROM rate_limits
GROUP BY 1
