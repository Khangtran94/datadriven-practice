with dec AS
(SELECT call_id,call_time
FROM api_calls 
WHERE strftime('%Y-%m',call_time) = '2026-12')

SELECT COUNT(*)::decimal AS after_hours_count FROM dec
