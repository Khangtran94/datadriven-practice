---
week: 3
folder: week-03-the-register
title: The Register
format: python
domain: Energy / Utilities - smart meter billing
difficulty: 4
yoe_problem: 4-6
yoe_you: 3-5
yoe_gold: 6-9
confidence_you: medium
score: 0.7693
rank: 6/14
analysis: yes
---

# Week 3: The Register - Problem overview

Python handler · score 0.7693, rank #6 of 14 `[measured]` · analysis of your submission: [Claude_Analysis.md](./Claude_Analysis.md)

## 1. The problem in one paragraph

An electric utility is switching to a new billing system on the 1st. Every half hour, every smart meter reports the energy it used and its **register**, the total it has counted since installation, and a feed forwards each report as 1 JSON line. Billing needs **1 clean row per meter per half hour** (`meter_id`, `interval_end`, `usage_kwh`, `register_kwh`, `quality`) from about 901,000 records. Some meters report only the register, so a half hour's usage is the *difference* from the previous half hour, and a real reading must replace an estimate whenever it arrives.

## 2. Domain and real-world context

**Energy and utilities / smart metering (advanced metering infrastructure).** Meters count energy in a register that only goes up. Billing needs consumption per interval, so the system subtracts consecutive registers, and fills gaps with estimates until the real read arrives. If a half hour is stamped on the wrong side of the boundary, or an estimate overwrites a real read, a customer is billed for the wrong amount. This kind of interval data is the core of any meter-to-cash pipeline.

## 3. Difficulty: 4/5

| Measured | Value |
|---|---|
| Data conditions listed in the README | 19 `[measured]` |
| Output columns | 5 `[measured]` |
| Records in the stream | 900,971 `[measured]` |
| Interface | `process` per line, `finalize` at the end `[measured]` |
| Hidden requirements | usage from register differences (needs the previous interval); real read beats estimate; interval stamped at start vs end; clock time with CDT/CST labels `[measured]` |
| Hard limits | none stated; "work per record" is a scored metric (3.0x median for your run) `[measured]` |

Why 4: 19 conditions, just under the 20-35 band, but several are about time and ordering, so records interact across a meter's history. It would be harder with a hard memory limit or many more units.

## 4. Problems the data throws at you

1. **Time is ambiguous.** Local wall-clock times labelled CDT or CST (8%), where on the fall-back night 01:30 happens twice and only the label tells them apart; some head-ends stamp the *start* of the half hour instead of the end (5%) and, read as an end, every such row overwrites the previous half hour; epoch seconds or milliseconds (5%).
2. **Usage that is not in the record.** Older meters report only the register (20%), so usage is the difference from the previous half hour's register, which has to be taken in interval order, even when reads arrive late in a burst (3%).
3. **Real read vs estimate.** A fill-in is replaced by the real read whenever it lands (10%), and a replay can re-send an estimate after the real read went out; the real read must still stand. Read flags differ per maker (6%), and workflow flags outside the contract (1%) become unknown.
4. **Units and envelopes.** Watt hours instead of kWh (8%), where the unit may sit in the value, in a field name or beside the number; CDC envelopes (2.5%) where the row is the *after* image; JSON serialized twice into a quoted string (2%).
5. **Dirty text and structure.** Key order (30%), nulls as strings (15%), padding and casing of meter ids (6%), bookkeeping fields (10%), broken JSON (2%), numbers as strings (5%), duplicates (2%), truncated lines (0.5%).

## 5. Data-engineering concepts to know

| Concept | What it means in this problem | Search keywords |
|---|---|---|
| Interval data and cumulative registers | Usage = register(now) - register(previous) | `AMI interval data`, `cumulative counter delta`, `meter register` |
| Stateful stream processing | Keep each meter's register history to compute differences | `per-key state`, `keyed state`, `stateful streaming` |
| Out-of-order and late data | A burst of reads arrives in interval order after an outage | `late arriving data`, `out-of-order events`, `watermark` |
| Precedence rules | Real read beats estimate; newest correction wins | `source precedence`, `merge by priority`, `upsert` |
| Time zones and DST | `01:30 CDT` and `01:30 CST` are different instants | `DST fold`, `ambiguous local time`, `tz database` |
| Interval boundary conventions | Start-stamped vs end-stamped intervals | `interval start vs end`, `right-closed interval` |
| Change data capture (CDC) | Envelope with before/after images; use the after | `CDC envelope`, `debezium`, `before after image` |
| Unit conversion | Wh to kWh from a field, a suffix or a unit column | `unit normalization`, `Wh vs kWh` |
| Double serialization | A JSON string that contains JSON | `nested json string`, `json.loads twice` |

A short example for the register difference (usage is only valid when both registers are known and in order):
```python
usage_kwh = register_now - register_prev
```

## 6. Estimated years of experience (YoE)

| | Range | Confidence | Deciding evidence |
|---|---|---|---|
| What the problem needs | **4-6 years** | medium | per-meter state with ordering, precedence rules, time-zone ambiguity, late data |
| Your code (`handler.py`) | **3-5 years** | medium | 336 lines; per-meter sorted register lists (L264-L266), a usage step from the neighbouring register (L294-L308), an `actual > estimated` ranking (L18), dedup and merge helpers (L269-L293); a naive time is assumed UTC (L153) so local CDT/CST labels are not resolved `[inferred]` |
| Gold code (`gold_submit.py`) | **6-9 years** | medium | text repair for broken and truncated JSON (L360-L443), CDC unwrap and correction detection (L545-L584), interval alignment (L343-L359), a `Handler` that merges by rank (L686-L772) |

- The gap is three specific skills: resolving local times by their label, repairing damaged lines instead of dropping them, and carrying precedence rules through every merge.
- Caveat: these numbers describe the level of the problem and the code, not a person. The gold is a top result and may have been refined against feedback or written with tooling.

## 7. Common traps

- **Assuming every naive time is UTC.** Sign: rows shifted by 5-6 hours, and a duplicated hour on the fall-back night.
- **Reading a start-stamped interval as an end.** Sign: every row of one head-end overwrites the half hour before it.
- **Computing a difference in arrival order.** Sign: usage values that are negative or huge after an outage burst.
- **Letting a replayed estimate beat a real read.** Sign: `quality` flips back to estimated.
- **Mixing Wh and kWh.** Sign: usage values 1000x off for one head-end.
- **Taking the before image of a CDC envelope.** Sign: the row shows the value that was *replaced*.
- **Stopping at one `json.loads`.** Sign: a quoted-string record is dropped.
- **Dropping truncated lines whole.** Sign: you lose complete fields that were written before the cut.

## 8. Mindset difference (you vs gold)

Your handler solves the clean per-meter story: sort the registers, difference them, rank real over estimated. The gold solves the same story but assumes every layer of the line can be wrapped, repaired or mislabeled, and unwraps it before the business rules start. Bugs, before/after code and how to verify are in [Claude_Analysis.md](./Claude_Analysis.md).

## 9. Matching interview questions

1. **(mid)** How do you compute interval usage from a cumulative counter? *Hint: difference with the previous reading in time order; handle the first reading and counter resets.*
2. **(senior)** Reads arrive late and out of order. How do you keep the differences correct? *Hint: keep a per-key sorted history, recompute the neighbours when a late read arrives.*
3. **(mid)** What is wrong with converting a local time to UTC with a fixed offset? *Hint: DST; the same wall time can map to two instants.*
4. **(mid)** An estimate and a real read both exist for one interval. Which wins, and does arrival order matter? *Hint: precedence by type, not by arrival.*
5. **(senior)** You receive CDC envelopes. Which image do you load, and what happens with deletes? *Hint: the after image for inserts and updates; deletes need a decision.*

## 10. Learning path

**Order of study:** (1) time zones and DST → (2) per-key state and sorted history → (3) precedence merges → (4) tolerant parsing of wrapped JSON.

**Exercise 1 - Ambiguous hour (45 min).** Convert `2026-11-01 01:30` labelled CDT and CST to UTC with `zoneinfo`. *Self-check:* the two inputs give two different UTC instants one hour apart.

**Exercise 2 - Register differences (45 min).** Feed registers for one meter in shuffled order. *Self-check:* usage is identical to the sorted run, and a missing interval gives no fake usage.

**Exercise 3 - Estimate vs real (30 min).** Send `estimate, real, estimate-replay` for one interval. *Self-check:* the output is the real read in all arrival orders.

## 11. Links

- Analysis of your submission: [Claude_Analysis.md](./Claude_Analysis.md)
- Challenge on the platform: [The Gauntlet - Week 3](https://datadriven.io/community/week-3)
