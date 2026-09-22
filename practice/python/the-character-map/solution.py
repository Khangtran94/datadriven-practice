def the_character_map(records):
  total = {}
  for k, v in records:
    total[k] = total.get(k,0) + v
  return total
