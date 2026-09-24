def first_non_repeated(s: str) -> str:
  from collections import Counter
  new = dict(Counter(s))
  for k,v in new.items():
    if v == 1:
      return k 
      break
  return ""
