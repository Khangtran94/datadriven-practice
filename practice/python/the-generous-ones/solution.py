def biggest_tipper(user_ids: list[str], tips: list[float]) -> str:
    total = dict(zip(user_ids, tips))
    result = sorted(total.items(), key = lambda x: (-x[1],x[0])) 
    return result[0][0]
