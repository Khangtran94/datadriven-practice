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
These ranges are heuristic learning references, not validated benchmarks or an assessment of the user's overall competence.

| Skill | Approximate experience equivalent | Rationale |
|---|---|---|
| Parsing and normalization | 1–3 years | Heterogeneous payloads, timestamps, and units |
| Event-time and time-series reasoning | 2–4 years | Half-hour intervals and daylight-saving transitions |
| Stateful calculations and precedence | 2–4 years | Register differences, estimates, and corrections |
| Production data quality | 2–4 years | CDC, duplicates, and late arrivals |

**Challenge-level estimate: roughly 2–4 years of practical data engineering experience.** The README defines the domain; `handler.py` shows the streaming interface; `gold_submit.py` demonstrates one stateful approach. These sources estimate challenge scope, not the user's personal skill level.

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
