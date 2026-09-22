def sequential_word_pairs(text: str):
  full = text.split()
  total = []
  for i in range(len(full) - 1):
    total.append([full[i], full[i+1]])
  return total
