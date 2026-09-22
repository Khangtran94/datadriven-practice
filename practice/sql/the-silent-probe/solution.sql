SELECT check_id,	svc_name,	status,	latency::integer,	uptime,	checked,	region
FROM svc_health
WHERE latency IS NOT NULL
