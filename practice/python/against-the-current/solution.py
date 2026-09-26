def sum_column(lines, column_name):
  lines_iter = iter(lines)
  try:
    header_line = next(lines_iter)
  except StopIteration:
    return 0
  header = header_line.split(',')
  if column_name not in header:
    return 0
  index = header.index(column_name)
  total = 0
  for line in lines_iter:
    if not line:
      continue
    try:
      num = line.split(',')[index]
      total += float(num)
    except (ValueError,IndexError):
      continue
  return total
