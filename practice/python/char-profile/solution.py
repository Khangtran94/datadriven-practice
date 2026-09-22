def char_freq(s):
  from collections import Counter
  new = dict(Counter(s))
  return dict(sorted(new.items()))
