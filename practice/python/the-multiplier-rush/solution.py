def max_product_subarray(nums: list) -> int:
  total = []
  for i in range(len(nums)-1):
    total.append(nums[i] * nums[i+1])
  return max(total)
