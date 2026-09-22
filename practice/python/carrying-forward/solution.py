def running_total(nums):
  total = []
  new = 0
  for i in nums:
    new += i
    total.append(new)
  return total
