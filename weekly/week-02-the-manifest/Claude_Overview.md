---
week: 2
folder: week-02-the-manifest
title: The Manifest
format: python
domain: Media / Video streaming - encoding and delivery
difficulty: 4
yoe_problem: 4-6
yoe_you: 3-5
yoe_gold: 6-9
confidence_you: medium
score: 0.8266
rank: 3/9
analysis: yes
---

# Week 2: The Manifest - Problem overview

Python handler · score 0.8266, rank #3 of 9 `[measured]` · analysis of your submission: [Claude_Analysis.md](./Claude_Analysis.md)

## 1. The problem in one paragraph

A video streaming service encodes every title into several quality levels, called renditions. A feed has logged 1 JSON line per rendition since 2020, and 10 days before a launch weekend the delivery team needs **1 clean row per `(title_id, rendition)`** (`title_id`, `rendition`, `codec`, `bitrate_kbps`, `duration_s`, `packaged_at`) to decide what to cache near viewers. The newest package run wins when a rendition was packaged more than once. The stream has about 929,000 records, and some facts about a rendition arrive on a *different line* than the rendition itself.

## 2. Domain and real-world context

**Media and entertainment / video streaming (encoding and delivery).** Streaming services use adaptive bitrate: each title exists as a "ladder" of renditions (for example 240p to 2160p), and the player switches between them as the network changes. The delivery team decides which renditions to pre-load on edge servers (CDN) before a launch. A wrong codec, bitrate or a missing rendition means viewers get a worse stream or the cache is warmed with the wrong files.

## 3. Difficulty: 4/5

| Measured | Value |
|---|---|
| Data conditions listed in the README | 20 `[measured]` |
| Output columns | 6 `[measured]` |
| Records in the stream | 928,817 `[measured]` |
| Interface | `process` per line, `finalize` at the end `[measured]` |
| Hidden requirement | the title for a job lives on a *close line* that arrives after its outputs, so outputs must wait for context `[measured]` |
| Cross-record rules | newest package run wins; duplicates; re-delivered older runs `[measured]` |

Why 4: 20 conditions at the edge of the 20-35 band, plus real cross-line state (close lines carry the title; the newest run must win). It is not 5 because the README states no hard resource limit. It would be harder if the stream were much larger than memory.

## 4. Problems the data throws at you

1. **One rendition is split across lines.** The packager logs each output as it finishes with only a job id, and writes the job's close line, which carries the title, after the outputs (2.5% of the stream). Hard because an output row alone is incomplete, and the close line is not a row.
2. **The same fact in many encodings.** Rendition as `WxH`, a bare height, a nickname like FHD, or an object with width and height (6%, and scope titles are wider than 16:9 so the rung is read from the width); codec tags from 3 toolchains (6%); rate in bps, Mbps or `k` (6%); length as milliseconds, timecode, ISO 8601 duration or minutes (6%); epoch seconds or milliseconds (4%); mixed date formats (4%).
3. **Missing values in disguise.** Sentinels such as `0`, `-1`, `NaN` (3%) and nulls spelled as strings (15%). Hard because a rendition is never 0 kbps, so the magnitude tells you it is missing.
4. **Damaged structure.** Key order (30%), broken JSON with a timestamp prefix or a byte-order mark (3%), nested fields moved over 2 rewrites (4%), keys in camelCase, UPPER_CASE or kebab-case (4%), bookkeeping fields (10%), truncated lines (0.5%).
5. **Identity and recency.** Duplicates (2%), a backfill re-delivering an older run (2%) that must *not* overwrite a newer one, and codecs outside the contract (1%) that become null.

## 5. Data-engineering concepts to know

| Concept | What it means in this problem | Search keywords |
|---|---|---|
| Adaptive bitrate (ABR) renditions | The "ladder" of quality levels per title | `HLS DASH renditions`, `bitrate ladder`, `ABR` |
| Stateful stream processing | Hold outputs until the job's close line arrives | `buffering by key`, `stream join`, `late context` |
| Last-write-wins by event time | The newest `packaged_at` wins, not the last line read | `event time vs arrival order`, `LWW`, `versioned upsert` |
| Unit normalization | bps, kbps, Mbps to one unit | `unit conversion`, `bitrate units` |
| Duration formats | ms, `HH:MM:SS` timecode, ISO 8601 `PT1H2M3S` | `ISO 8601 duration`, `timecode parsing` |
| Sentinel values | `0`, `-1`, `NaN` meaning "unknown" | `sentinel null`, `missing value encoding` |
| Tolerant parsing | Strip prefixes and byte-order marks, repair quoting | `BOM`, `log line prefix`, `lenient json` |
| Bounded state | Keep only what is still needed (open jobs, newest row per key) | `memory-bounded streaming`, `state size` |
| Contract validation | Only 4 codecs are valid; others become null | `enum validation`, `data contract` |

A short example for "newest run wins" (compare event time, not arrival order):
```python
if new["packaged_at"] > held["packaged_at"]: held = new
```

## 6. Estimated years of experience (YoE)

| | Range | Confidence | Deciding evidence |
|---|---|---|---|
| What the problem needs | **4-6 years** | medium | cross-line state (job close context), newest-run-wins, many unit/format normalizers at once |
| Your code (`handler.py`) | **3-5 years** | medium | 287 lines with an alias map and per-field normalizers (L59-L225), a quality gate (L226-L244), and newest-wins state keyed on `(title_id, rendition)` (L263-L284); no handling of job close lines `[inferred]` (no mention of job or close in the file) |
| Gold code (`gold_submit.py`) | **6-9 years** | medium | a hand-written lenient JSON parser (L30-L204), per-job pending buffers and context inheritance (L535-L632), conflict-aware merging at the same instant (L570-L590), compact state to limit memory (L633-L648) |

- The gap is a modelling step, not more regexes: seeing that a row is assembled from several lines, then buffering until the context arrives.
- Caveat: these numbers describe the level of the problem and the code, not a person. The gold is a top result and may have been refined against feedback or written with tooling.

## 7. Common traps

- **Treating every line as a row.** Sign: close lines produce junk rows or are dropped with their titles.
- **Taking the last line read as the newest.** Sign: a backfill overwrites a newer package run.
- **Assuming one rate unit.** Sign: bitrates 1000x too large or small.
- **Reading the rung from the height.** Sign: wide-aspect titles land in the wrong rung.
- **Using `0` or `-1` as a value.** Sign: durations of 0 seconds in the output.
- **Parsing only the first `{`.** Sign: lines with a timestamp prefix are lost.
- **Keeping every raw line in memory.** Sign: memory grows linearly with the stream.
- **Guessing when two versions conflict at the same instant.** Sign: values flip between runs of the same input.

## 8. Mindset difference (you vs gold)

Your handler treats each line as a record to clean and compare. The gold treats the stream as a set of *jobs*: outputs wait for their job's context, and only then become rows. That is why it recovers lines your approach cannot see at all. Bugs, before/after code and how to verify are in [Claude_Analysis.md](./Claude_Analysis.md).

## 9. Matching interview questions

1. **(mid)** A record is split across two lines that arrive in either order. How do you assemble it? *Hint: buffer by a shared key, emit when complete, flush leftovers at the end.*
2. **(mid)** Two versions of a row arrive; which wins? *Hint: compare event time, not arrival order; define a tie-break.*
3. **(mid)** The same metric arrives in bps, kbps and Mbps. How do you normalise it? *Hint: infer the unit from magnitude and name, and sanity-check the range.*
4. **(senior)** How do you keep state bounded in a stream with 1M lines? *Hint: store only the newest compact row per key and drop closed jobs.*
5. **(senior)** Two sources disagree at the same instant. What do you do? *Hint: do not guess; fill holes only and mark or null the conflicting cell.*

## 10. Learning path

**Order of study:** (1) tolerant parsing and key normalization → (2) unit and duration parsing → (3) newest-wins state → (4) buffering by job id.

**Exercise 1 - Duration parser (30-45 min).** Accept `90000`, `00:01:30`, `PT1M30S` and `1.5` (minutes). *Self-check:* all four give 90 seconds.

**Exercise 2 - Newest-wins state (45 min).** Feed 6 lines for 3 keys in shuffled order, some older than others. *Self-check:* the output holds the newest version of each key regardless of order.

**Exercise 3 - Close lines (60 min).** Emit outputs for job `J1` without a title, then a close line with the title. *Self-check:* the rows appear with the title, a job with no close line is flushed at the end, and the close line itself is not a row.

## 11. Links

- Analysis of your submission: [Claude_Analysis.md](./Claude_Analysis.md)
- Challenge on the platform: [The Gauntlet - Week 2](https://datadriven.io/community/week-2)
