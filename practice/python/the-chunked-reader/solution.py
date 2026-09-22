def chunked_read(lines: list, chunk_size: int):
  total = []
  for i in range(0,len(lines), chunk_size):
    total.append(lines[i:i+chunk_size])
  return total
