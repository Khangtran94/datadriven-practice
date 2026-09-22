def most_frequent(items: list) -> list:
    from collections import Counter
    counts = Counter(items)
    return sorted([k for k,v in counts.items() if v == max(counts.values())])
