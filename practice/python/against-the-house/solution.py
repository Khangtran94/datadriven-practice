def dice_roll_scoring(dice: list[int]):
  from collections import Counter
  cnt = Counter(dice)
  new = [[n,f] for n,f in cnt.items()]
  if len(set(dice)) == 1:
    return 50
  elif new[0][1] == 4 and len(new) == 2:
    return 40
  elif new[0][1] == 3 and len(new) == 2:
    return 25
  else:
    return sum(dice)
