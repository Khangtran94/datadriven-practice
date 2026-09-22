def most_reviewed_restaurant(reviews: dict) -> str:
  total = {}
  for k,v in reviews.items():
    total[k] = len(v)
  return max(total, key = total.get)
