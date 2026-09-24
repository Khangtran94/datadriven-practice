def check_string_permutation(s1: str, s2: str) -> bool:
  from collections import Counter
  if Counter(s1) == Counter(s2):
    return True
  else:
    return False
