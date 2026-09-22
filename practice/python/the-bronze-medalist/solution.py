def find_kth_largest(nums: list, k: int) -> int:
  new = sorted(nums, reverse = True)
  goal = new[k - 1]
  return goal
