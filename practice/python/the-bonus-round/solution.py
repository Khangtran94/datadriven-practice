def dice_score(rolls: list[int]) -> int:
  total = sum(rolls)
  for i in range(len(rolls) - 1):
    if rolls[i] == rolls[i+1]:
      total += (rolls[i] * 2)
  return total
