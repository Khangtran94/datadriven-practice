def product_except_self_no_div(nums: list) -> list:
  total = []
  for i in range(len(nums)):
    total.append(nums[:i] + nums[i+1:])
  
  result = []
  load = 1
  for i in range(len(nums)):
    for j in range(len(total[1])):
      load *= total[i][j]
    result.append(load)
    load = 1 
  return result
