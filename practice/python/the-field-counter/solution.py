def count_key_occurrences(records, key):
  from collections import defaultdict
  total = defaultdict(int)
  for record in records:
    if key in record:
      total[record[key]] += 1
  return dict(total)
