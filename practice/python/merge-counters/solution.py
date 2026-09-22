def merge_dicts(d1, d2):
  total = {}
  for d in d1:
    if d in d2:
        total[d] = d1[d] + d2[d]
    else:
        total[d] = d1[d]
  for d in d2:
    if d not in d1:
        total[d] = d2[d]
  return total
