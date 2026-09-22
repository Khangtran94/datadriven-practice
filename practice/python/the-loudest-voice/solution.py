from collections import Counter

def majority_event_in_stream(events: list[str]):
    count = Counter(events)
    check = len(events) // 2

    for k, v in count.items():
        if v > check:
            return k

    return None
