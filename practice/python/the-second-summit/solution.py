def second_largest_no_builtins(nums: list[int]) -> int:
  return list(sorted(set(nums),reverse =True))[1]
