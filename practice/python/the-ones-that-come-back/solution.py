def find_duplicates_only(nums: list[int]) -> list[int]:
  return sorted(list(set([i for i in nums if nums.count(i) > 1])))
