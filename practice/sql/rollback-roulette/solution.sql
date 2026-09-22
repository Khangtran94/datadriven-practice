SELECT
  COUNT(*) AS failed_deployments
FROM deploy_logs
WHERE status ILIKE 'failed' AND svc_name = 'payment-api'
