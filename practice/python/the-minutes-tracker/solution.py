def total_activity_minutes(record):
  total = 0
  for i in record['activities']:
    total += i['minutes']
  return total
