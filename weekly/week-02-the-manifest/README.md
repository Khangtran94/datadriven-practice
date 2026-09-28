# Week 2: The Manifest

*A launch weekend is 10 days out and the delivery team needs to know what is ready to play. The only record is a feed nobody has read in 6 years.*

[The Gauntlet on DataDriven](https://datadriven.io/community/week-2)

You're a data engineer at a video streaming service. Every title is encoded into several quality levels, called renditions, and a feed has logged 1 JSON line per rendition since 2020. Before a launch weekend, the delivery team needs 1 clean row per rendition to decide what to cache near viewers, and the feed is the only record of what was made. Write the code that turns it into that table.

## Result

| | |
|---|---|
| Score | 0.8266 |
| Rank | #3 of 9, top 33% |
| Points | +120 |
| Records recovered | 806,315 of 928,817 |
| Work per record | 2.1x median |
| Statements | 178 |
| Scored | 2026-09-27 |

14 rows were a second row for a key already emitted. Together they cost 28 points.

## Columns

| Column | Correct | Wrong | Missed |
|---|---:|---:|---:|
| `bitrate_kbps` | 80% | 50,848 | 133,386 |
| `codec` | 82% | 1,023 | 161,388 |
| `duration_s` | 83% | 38,400 | 120,573 |
| `title_id` | 87% | 0 | 122,502 |
| `rendition` | 87% | 0 | 122,502 |
| `packaged_at` | 87% | 2,086 | 119,970 |

## What the stream held

Every condition in the data, ordered by what it cost. "Handled" means its records came through about as well as the rest of the run.

| Condition | Of stream | Recovered | Handled |
|---|---:|---:|:---:|
| Key order changes | 30.0% | 84% | yes |
| Rung as size, name or number | 6.0% | 27% | no |
| Nesting and flattening | 4.0% | 28% | no |
| Job close lines | 2.5% | 1% | no |
| Broken JSON structure | 3.0% | 36% | no |
| Epoch seconds or millis | 4.0% | 53% | no |
| Mixed date formats | 4.0% | 53% | no |
| Export bookkeeping fields | 10.0% | 84% | yes |
| Codec tags from 3 toolchains | 6.0% | 74% | no |
| Rate unit drift: bps, Mbps, k | 6.0% | 74% | no |
| Length as ms, timecode or ISO | 6.0% | 78% | no |
| Sentinels in place of null | 3.0% | 67% | no |
| Padding and casing | 6.0% | 85% | yes |
| Numbers as strings | 5.0% | 85% | yes |
| Key names in another case | 4.0% | 86% | yes |
| Nulls spelled as strings | 15.0% | 85% | yes |
| Truncated lines | 0.5% | 1% | no |
| Duplicate records | 2.0% | 91% | yes |
| Codec outside the contract | 1.0% | 84% | yes |
| Re-delivery of an older run | 2.0% | 93% | yes |

### Why these happen

**Key order changes.** JSON objects are unordered, and the packager builds them from a dict. Key order carries no meaning and should never be relied on.

**Rung as size, name or number.** Profiles were named by whoever set them up: a WxH pair, a bare height, a nickname like FHD, or an object with width and height. Scope titles are wider than 16:9, so the rung is read from the width, not the height.

**Nesting and flattening.** 2 rewrites moved fields in and out of sub-objects (video, asset, timing), and old lines were never migrated. The same value sits at different depths depending on when it was written.

**Job close lines.** The in-house packager logs each output as it finishes with only its job id, and writes the job's close line, which carries the title, after the outputs. The close line itself names no rendition, so it is not a row.

**Broken JSON structure.** The feed is written by a logger, not a serializer: lines carry a timestamp prefix, a byte-order mark from a Windows host, a stray trailing character, or quoting that depends on the values. A strict parser rejects the whole line.

**Epoch seconds or millis.** Different services wrote the same field as epoch seconds or milliseconds, sometimes as a string. Both look like plausible integers.

**Mixed date formats.** Timestamps were written by systems with different conventions, some with no zone at all and some in the packager host's local offset. A naive time needs the feed's own rule to resolve.

**Export bookkeeping fields.** The feed adds its own batch, packager and ingestion markers. They describe the run that wrote the line, not the rendition, and do not belong in the table.

**Codec tags from 3 toolchains.** Each packager writes the codec the way its own config or the playlist standard names it: an RFC 6381 tag with a profile suffix, a library name, or the marketing name. All of them mean 1 of 4 codecs.

**Rate unit drift: bps, Mbps, k.** 1 toolchain reports the rate in bits per second, another as a human string with a unit, a third rounds it for its dashboard. A rendition is never 6 kbps, so the magnitude says which.

**Length as ms, timecode or ISO.** Video tooling has 4 native ways to say how long a file is: milliseconds, a timecode, an ISO 8601 duration from the DASH manifest, and minutes for the catalog. Each was pasted through unchanged.

**Sentinels in place of null.** A probe that fails returns 0 or -1 and the job carries on. A float that was never set serializes as NaN. None of these is a length or a rate; they are the absence of one.

**Padding and casing.** Title ids and profile names were pasted into job configs by hand. The packager writes them back exactly as configured, spaces and capitals included.

**Numbers as strings.** Values that passed through a shell template or a CSV stage arrive quoted. The number is intact; the type is not.

**Key names in another case.** 1 toolchain emits camelCase, 1 emits UPPER_CASE from its shell templates, and a vendor's exporter writes kebab-case. The keys are the same words in another dress.

**Nulls spelled as strings.** An encoder that could not probe a value writes whatever its template had for absence. 3 toolchains and a CSV round trip left the feed with several spellings of nothing.

**Truncated lines.** Writes that hit a buffer or a container stop mid-line leave a partial record. What was written before the cut is still real; the rest is gone.

**Duplicate records.** Retries and overlapping batch windows resend lines that already went out. At-least-once delivery is the norm, so the reader has to settle identity.

**Codec outside the contract.** Mezzanine and archive renditions were packaged by the same jobs for a while. Their codecs are real, but they are not 1 of the 4 the player ladder is built from, so they stage as null.

**Re-delivery of an older run.** A backfill replays old batches, so a rendition already re-packaged by a newer run turns up again with the older run's rate, codec and time. The newest package run is the one the players use, so it wins; the order lines arrive in says nothing.

Concepts exercised: pyArithmetic, pyBooleanOps, pyBreakContinue, pyClassBasic, pyCsvJson, pyDataTypes, pyDictComprehension, pyDictCreate, pyDictIterate, pyDictMethods, pyDictNested, pyDunderMethods, pyExceptionTypes, pyFStrings, pyForBasic, pyFuncDef, pyGuardClauses, pyIfElse, pyJsonHandling, pyListCreate, pyListModify, pyMathOps, pyModules, pyNestedComprehensions, pyNestedLoops, pyRegex, pySets, pySlicing, pyStringBasic, pyStringMethods, pyTernary, pyTryExcept, pyTuples, pyTypeConversion, pyUnpacking, pyVariables

## Submission

The handler that was graded is in [`handler.py`](./handler.py).
