def aggregate_trips(trips: list[dict]) -> list[dict]:
  # trips: [{'user_id': str, 'origin': str, 'destination': str, 'duration_hours': int}]
  from collections import defaultdict
  total = defaultdict(lambda: {'total_hours':0,'destinations':set()})
  for trip in trips:
    user_id = trip['user_id']
    total[user_id]['total_hours'] += trip['duration_hours']
    total[user_id]['destinations'].add(trip['destination'])
  final = [{'user_id':user_id,
          'total_hours':data['total_hours'],
          'unique_destinations':len(data['destinations'])}
          for user_id, data in total.items()]
  return sorted(final, key = lambda x:x['user_id'])
