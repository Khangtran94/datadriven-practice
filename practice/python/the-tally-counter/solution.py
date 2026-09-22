def count_occurrences(nums: list, target: int) -> int:
  from collections import Counter
  total = Counter(nums)
  return total[target]
