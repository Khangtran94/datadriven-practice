def string_to_number_mapping(s: str) -> dict:
  total = {}
  for index, char in enumerate(s):
    if char not in total:
       total[char] = index
  return total
