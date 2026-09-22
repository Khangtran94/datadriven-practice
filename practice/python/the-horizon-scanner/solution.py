def next_greater_element(nums):
  total = []
  if not nums:
    return []
  if len(nums) > 1:
    for i in range(len(nums)):
      found = False
      for j in range(i+1,len(nums)):
        if nums[j] > nums[i]:
          found = True
          total.append(nums[j])
          break
      if not found:
        total.append(-1)
    return total
  else:
    return [-1]
