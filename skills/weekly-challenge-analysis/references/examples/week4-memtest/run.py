import sys, time, resource, importlib, json
mod = importlib.import_module(sys.argv[1]); path = sys.argv[2]; dump = sys.argv[3] if len(sys.argv) > 3 else None
H = mod.Handler(); n = 0; t0 = time.time()
with open(path) as f:
    for line in f:
        H.process(line); n += 1
rss_proc = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024
rows = H.finalize()
out = open(dump, "w") if dump else None
n_rows = 0
for r in rows:                      # works for a list or a generator; nothing is accumulated here
    n_rows += 1
    if out: out.write(json.dumps(r, sort_keys=True) + "\n")
rss_peak = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024
print(f"{sys.argv[1]:18s} lines={n:>9,} rows={n_rows:>8,}  peak after process={rss_proc:5.0f} MB  peak after finalize={rss_peak:5.0f} MB  time={time.time()-t0:4.0f}s")
