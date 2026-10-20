# Week 4 memory test (worked example)

- `gen.py <n_keys> <out.jsonl>`: writes a synthetic HL7-in-JSON log (revisions, replays, re-sends).
- `run.py <module> <log.jsonl> [dump.out]`: streams the log through `Handler.process`, iterates `finalize`
  (list or generator), prints peak RSS after each phase, optionally dumps rows for comparison.
- `after_class.py`: the proposed memory-bounded `Handler` (helpers from the original handler.py L1-317 go above it).

To reproduce: copy the original handler as before_handler.py; build after_handler.py = first 317 lines of it + after_class.py;
`python3 gen.py 750000 full.jsonl`, then `python3 run.py before_handler full.jsonl b.out` and `python3 run.py after_handler full.jsonl a.out`,
and compare `sort b.out` with `sort a.out`.
Results on the 997,500-line stream: before 1,239 MB peak; after 453 MB (list) / 233 MB (generator); identical rows.
