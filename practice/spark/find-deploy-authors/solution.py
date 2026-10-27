(deploy_logs
  .filter(F.lower('author') == 'alice')
  .select('author')
  .distinct())
