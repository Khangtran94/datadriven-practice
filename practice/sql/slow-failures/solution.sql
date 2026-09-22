SELECT endpoint, status, latency, err_msg
FROM api_calls
WHERE latency > 200 AND status >= 400
ORDER BY latency DESC
