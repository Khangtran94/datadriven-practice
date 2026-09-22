def top_box_office(movies: list[dict], n: int) -> list[str]:
  from collections import Counter
  total = Counter()
  for i in movies:
    total[i['actor']] += i['earnings']
  total = dict(total)
  total = sorted(total.items(), key = lambda x:x[1], reverse=True)
  return [actor for actor, _ in total[:n]]
