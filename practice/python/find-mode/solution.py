def most_frequent(lst):
  from collections import Counter
  count = Counter(lst)
  e, f = count.most_common(1)[0]
  return e
