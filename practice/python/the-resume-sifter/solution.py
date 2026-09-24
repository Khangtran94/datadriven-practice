def filter_new_resumes(urls: list[str], existing_ids: set[str]) -> list[list[str]]:
  link = [u[19:] for u in urls]
  total = []
  for l in link:
    parts = l.split('_')
    name = '_'.join(parts[:-1])
    number = parts[-1]
    total.append([name,number])
  return [(name, number) for name, number in total if number not in existing_ids]
