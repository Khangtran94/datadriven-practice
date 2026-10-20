# When a run scores 0 or crashes

Lessons from Week 4 (score 0, 512 MB limit):

- **The sample hides memory problems.** A 300-line sample shows mostly Python's own footprint (19/512 MB).
  Measure at 20k, 200k and ~1M synthetic lines and look at the slope.
- **Memory grows with what is stored, not what is done.** Work per record was near the winner's;
  the handler kept every candidate and a fingerprint of every line (about 1.2 GB at 1M lines).
- **If `process()` returns `[]`, a stop before `finalize()` scores nothing.** The state must be bounded.
- **Fix pattern:** keep one small packed state per key (reconcile on arrival), drop per-line fingerprints,
  store ints/`struct` bytes instead of dicts, free state while building rows, and try a generator
  `finalize` on the sample run before relying on it.
- **The output costs too.** 750k row dicts were about 200 MB by themselves.
- **Prove equivalence.** Run the old and new handlers on the same synthetic stream and compare rows.
  Also stress-test any pruning rule against the original resolution rules with random histories.

Always report what was measured by the platform, what was measured locally, and what was only estimated.

How to measure locally (see examples/week4-memtest/): write a generator from the README's conditions,
stream the file through `process`, then iterate `finalize`, and record `resource.getrusage(RUSAGE_SELF).ru_maxrss`
after each phase. Compare against the platform's limit.
