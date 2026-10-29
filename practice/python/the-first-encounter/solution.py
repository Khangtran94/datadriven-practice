def string_to_number_mapping(s: str) -> dict:
  total = {}
  for i, char in enumerate(s):
    if char not in total:
      total[char] = i
  return total
