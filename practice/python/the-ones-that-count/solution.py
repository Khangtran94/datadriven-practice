def activity_time_ledger(activities: list[dict], targets: list[str]) -> int:
  total = 0
  for a in activities:
    for t in targets:
      if a.get('name') == t:
        total+=a.get('minutes')
  return total
    
