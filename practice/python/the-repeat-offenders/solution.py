def the_repeat_offenders(items: list):
    from collections import Counter
    return [i for i,v in Counter(items).items() if v > 1]
