def prefix_sum(nums):
  new = 0
  total = []
  for i in nums:
    new += i
    total.append(new)
  return total
