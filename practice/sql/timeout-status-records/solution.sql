SELECT *
FROM svc_health
where lower(status) = 'timeout'
