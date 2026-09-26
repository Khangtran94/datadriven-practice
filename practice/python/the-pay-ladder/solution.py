def top_n_salaries(employees: list[dict], n: int) -> list[int]:
  salary = sorted(set([e['salary'] for e in employees]),reverse=True)
  if n > len(salary):
    return salary
  else:
    return salary[:n]
