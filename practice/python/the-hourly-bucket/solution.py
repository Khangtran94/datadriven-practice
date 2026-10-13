def group_by_hour(events):
  from collections import defaultdict
  total = defaultdict(list)
  for event in events:
    hour = event['ts'][:13]
    total[hour].append(event['type'])
  return total
