def group_by_key(words):
  from collections import defaultdict
  total = defaultdict(list)
  for w in words:
    total[w[0]].append(w)
  return dict(total)
