def group_averages(data):
  total = {}
  count = {}
  for d in data:
    key = d[0]
    value = d[1]
    total[key] = total.get(key,0) + value
    count[key] = count.get(key,0) + 1
  result = {}
  for k in total:
    result[k] = total[k] / count[k]
  return result
