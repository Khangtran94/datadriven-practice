def majority_element(nums: list[int]) -> int:
  from collections import Counter
  count = Counter(nums)
  for i in count:
    if count[i] > (len(nums) // 2):
      return i
