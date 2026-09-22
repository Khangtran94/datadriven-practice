def word_counts(text: str) -> dict:
  from collections import Counter
  total = Counter(text.split(' '))
  return dict(sorted(total.items(), key = lambda x:x[1], reverse=True))
