def cumulative_product(nums: list) -> list:
  total = []
  new = 1
  for i in range(len(nums)):
    new *= nums[i]
    total.append(new)
  return total
