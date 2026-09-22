def count_occur(lst: list, target) -> int:
  appear = 0
  for i in lst:
    if i == target:
      appear += 1
  return appear
