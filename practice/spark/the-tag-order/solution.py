(
deploy_logs.filter(F.lower('status')=='failed')
.select('log_id',F.lower('env_name'))
)
