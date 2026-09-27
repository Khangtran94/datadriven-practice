def the_solo_act(codes: list[int]):
  from collections import Counter
  cnt = dict(Counter(codes))
  return [k for k,v in cnt.items() if v == 1]
