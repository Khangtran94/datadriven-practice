def are_anagrams(s1, s2):
  from collections import Counter
  check_s1 = Counter(s1.lower())
  check_s2 = Counter(s2.lower())
  if check_s1 == check_s2:
    return True
  else:
    return False
