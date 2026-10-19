# Week 3: The Register — Challenge Overview

## 1. Challenge at a Glance
Reconstruct billing-grade half-hour electricity usage from smart-meter events containing direct usage, cumulative registers, estimates, corrections, and late deliveries.
- **Input:** JSON-like meter events, sometimes double-encoded or wrapped in CDC envelopes.
- **Output grain:** one row per meter per half-hour interval.
- **Fields:** `meter_id`, `interval_end`, `usage_kwh`, `register_kwh`, `quality`.
- **Core techniques:** event-time processing, unit conversion, stateful calculation, quality precedence, and deduplication.

## 2. Domain Knowledge
A **register** is a cumulative energy counter. **Interval usage** is consumption during a half-hour. When only cumulative values exist, usage can be derived as current register minus the previous valid register. Devices may label an interval by its start or end. Estimated/substituted reads are not equivalent to actual reads. CDC envelopes can contain before and after images.

## 3. Business Rules and Output Contract
Unwrap supported JSON and CDC envelopes and select the correct after-image. Normalize meter IDs, timestamps, and Wh/kWh units. Convert interval-start timestamps where required. Normalize maker-specific quality flags. Derive usage from registers only after ordering by event time per meter. Apply explicit precedence so a replayed estimate cannot overwrite an actual read. Handle duplicates and late arrivals deterministically and emit one row per meter/interval. Register decreases require explicit reset/rollover rules rather than an automatic assumption of negative consumption.

## 4. Difficulty Assessment
**Intermediate-to-advanced stateful streaming.** The meaning of a reading depends on event time, quality, neighboring readings, and correction history. A stateless one-line transform cannot correctly derive every register difference without keyed state or buffering.

## 5. Estimated Experience Equivalence

These estimates distinguish challenge difficulty from the patterns demonstrated in the submission and reference solution. They are heuristic learning references, not validated hiring benchmarks or a measurement of the author's overall ability.

### 5.1. Overall Comparison

| Evidence Source | Lens | Level | Estimated YoE | Short Rationale |
|---|---|---|---|---|
| Problem statement (README.md) | Challenge difficulty | Mid-level to Senior-level problem-solving | Approximately 2–4 years of relevant data-engineering experience | Combines dirty JSON, interval identity, local time and daylight-saving transitions, start-vs-end timestamp conventions, cumulative register differencing, quality ranking, unit conversion, CDC envelopes, and late reads. |
| Your submission (handler.py) | Demonstrated implementation | Mid-level patterns | Approximately 2–3 years equivalent for the patterns demonstrated | Defines alias maps, JSON recovery, unit factors, quality mappings, and normalization helpers. Contract coverage still needs validation for interval alignment, DST ambiguity, chronological register differencing, and actual-versus-estimated precedence. |
| Reference solution (gold_submit.py) | Solution sophistication | Senior-level problem-solving patterns | Approximately 4–5 years of relevant experience | Has broad field aliases, null/bookkeeping filters, multiple time/unit conventions, and richer stateful logic for choosing and deriving meter readings. |

These ranges are not requirements for solving the task and should not be interpreted as the author's actual years of experience.

### 5.2. Skill-by-Skill Comparison

| Skill Group | Problem Target | Submission Evidence | Reference Evidence |
|---|---|---|---|
| JSON and schema normalization | Junior–Mid | JSON recovery, flattening, and key aliases | Broader aliases and defensive payload normalization |
| Meter identity normalization | Junior–Mid | Alias map and ID pattern | Wider set of meter identifier variants |
| Timestamp and interval semantics | Mid–Senior | Timestamp parsing exists; start-stamped intervals and DST need explicit verification | More extensive time-source and interval normalization |
| Energy unit conversion | Mid | Wh/kWh/MWh factors are defined | Broad unit aliases and numeric normalization |
| Register-to-usage calculation | Mid–Senior | Verify readings are ordered by interval before differencing | More developed time-series and state handling |
| Actual versus estimated quality | Mid–Senior | Quality aliases and ranks are defined | Broader actual/estimated vocabulary and precedence |
| CDC and late-arriving data | Mid–Senior | Envelope parsing and sequence fields are present; late bursts need validation | More elaborate envelope, ordering, and candidate-selection handling |

### 5.3. Evidence Behind the Estimate

- Some meters provide only a cumulative register. Deriving interval usage requires differencing adjacent readings in chronological order.
- Local timestamps include CDT/CST and daylight-saving ambiguity; readings may be stamped at interval start instead of end. These are domain-time semantics, not just string parsing.
- The submission contains useful foundations: alias tables, unit factors, quality maps, and JSON recovery. The key question is whether these helpers are consistently applied to final state selection and differencing.
- The reference has broader aliases and richer time-series handling. That indicates a more comprehensive pattern, but correctness still depends on the contract and tests.

### 5.4. What Each Level Looks Like Here

| Level | Expected Demonstration |
|---|---|
| Beginner / Entry-level | Parses stable JSON fields and converts a known energy unit. |
| Junior Data Engineer | Normalizes meter IDs, common timestamps, nulls, and basic quality labels. |
| Mid-level Data Engineer | Defines canonical interval identity, converts units consistently, ranks competing reads, and computes usage from registers chronologically. |
| Senior-level problem-solving | Handles DST folds, start/end conventions, CDC wrappers, late bursts, estimate replays, and corrections without making output depend on arrival order. |

### 5.5. Assumptions and Limitations

1. README.md defines the business problem; handler.py and gold_submit.py provide implementation evidence.
2. A declared helper or mapping is evidence of intended handling, not proof that every input path is covered correctly.
3. DST and local-time rules must follow the challenge's source-specific contract.
4. YoE ranges are approximate and depend on prior time-series and utility-domain exposure.
5. This assesses challenge scope and code patterns, not the author's overall career seniority.

**Overall conclusion:** Week 3 sits between Mid-level implementation and Senior-level time-series problem-solving. The submission demonstrates useful normalization foundations; the highest-value concepts to verify are canonical interval time, register differencing, and deterministic quality precedence.

## 6. Core Engineering Patterns
- Separate event time from processing/arrival time.
- Maintain keyed state or buffer readings until order is known.
- Apply explicit quality precedence for actual, estimated, and corrected readings.
- Interpret CDC before/after images correctly.
- Normalize units and interval boundaries before calculations.
- Make replays idempotent and define how late data changes derived intervals.

## 7. Common Traps
- Treating every timestamp as UTC or ignoring CDT/CST.
- Confusing interval start with interval end.
- Subtracting registers in arrival order.
- Allowing an old estimate to replace an actual read.
- Mixing Wh and kWh.
- Treating every unknown flag as a valid reading.
- Deduplicating raw JSON instead of meter/interval identity.

## 8. Independent Examples
**Register difference:** readings of 125.4 kWh and 126.1 kWh at consecutive half-hours imply 0.7 kWh usage if both are valid in the same register epoch.

**Late arrival:** reorder by event time before deriving usage even if the earlier interval arrives later.

**Quality precedence:** a replayed estimate should not displace an actual read when the contract gives actual reads priority.

## 9. Technical Topics to Study
1. Event time, processing time, time zones, and daylight-saving transitions.
2. Cumulative counters and time-series differencing.
3. Stateful stream processing and per-key buffering.
4. CDC images, late data, idempotency, and correction handling.

## 10. Suggested Learning Plan
1. Implement parsing and normalization first.
2. Normalize interval timestamps and units independently.
3. Derive usage from a small ordered series for one meter.
4. Add multiple meters with isolated keyed state.
5. Add quality precedence, duplicates, and replays.
6. Simulate late arrivals and different input orders.
7. Test daylight-saving transitions, missing intervals, and reset cases.

## 11. Validation Checklist
- [ ] Is each reading assigned to the correct meter and interval?
- [ ] Are time zones and start/end conventions correct?
- [ ] Are Wh and kWh converted consistently?
- [ ] Are CDC envelopes unwrapped correctly?
- [ ] Are register differences computed in event-time order?
- [ ] Are estimates and actuals resolved by explicit precedence?
- [ ] Are late records and replays deterministic?
- [ ] Is there exactly one row per meter and interval?

## 12. Evidence and Assumptions
The README documents smart-meter intervals, cumulative registers, quality flags, CDC, daylight-saving times, and late arrivals. `handler.py` and `gold_submit.py` were reviewed for interface and possible stateful techniques. Estimates are heuristic; resets, missing intervals, and ambiguous timestamps must follow the challenge's explicit rules.
