# Week 6: The Dwell

*A container terminal bills shipping lines for every day a container sits in its yard. The raw tables keep only a few nights.*

[The Gauntlet on DataDriven](https://datadriven.io/community/week-6)

You're a data engineer at a port's container terminal. The terminal charges each shipping line for every day a container sits in its yard, and billing needs one clean row per visit, a container's stay from ship to gate. Each night, a job copies 3 raw tables out of 2 source systems. The yard system provides unit_visit, a change log with a row for every visit that changed or was charged that night, and line_operator, a nightly snapshot of the shipping lines. Billing's tariff feed provides tariff_rate, a rate table that arrives in full on the first night; after that, only the rows that changed arrive. Write the DAG that builds billing's storage charges for the period ending 2026-10-19, from the nightly loads between 2026-09-25 and 2026-10-24.

## Result

| | |
|---|---|
| Score | 0.6853 |
| Rank | #3 of 5, top 60% |
| Points | +120 |
| Rows built | 43,311 of 48,948 |
| Work per raw row | 1.4x median |
| Statements | 4 |
| Scored | 2026-10-25 |

1,104 rows matched no record. Together they cost 2,208 points.

## Columns

| Column | Correct | Wrong | Missed |
|---|---:|---:|---:|
| `bill_to` | 23% | 0 | 37,511 |
| `gate_out_time` | 51% | 0 | 23,853 |
| `visit_state` | 68% | 5,055 | 10,652 |
| `booking_ref` | 80% | 0 | 9,915 |
| `unit_nbr` | 86% | 0 | 6,977 |
| `storage_usd` | 86% | 1,338 | 5,637 |
| `storage_in_period_usd` | 86% | 1,156 | 5,637 |
| `visit_gkey` | 88% | 0 | 5,637 |

## What the tables held

Every condition in the data, ordered by what it cost. "Handled" means its records came through about as well as the rest of the run.

| Condition | Of tables | Recovered | Handled |
|---|---:|---:|:---:|
| Copied on several nights | 86.7% | 70% | no |
| Charged over several nights | 50.3% | 70% | yes |
| Loaded after the run started | 40.9% | 70% | yes |
| Newest row missing fields | 45.0% | 70% | yes |
| The same row twice in a batch | 35.0% | 71% | yes |
| NULL written as text | 30.0% | 71% | yes |
| Days charged after the close | 30.7% | 74% | yes |
| Old rows in a newer batch | 25.0% | 63% | no |
| The gate app's own state words | 16.0% | 65% | no |
| Box numbers spaced or cased | 18.0% | 71% | yes |
| A state that came days late | 22.0% | 69% | yes |
| A rate change during the stay | 15.2% | 70% | yes |
| Line codes typed at the gate | 14.0% | 71% | yes |
| Camel-case JSON keys | 12.0% | 62% | no |
| Visit keys with leading zeros | 5.0% | 43% | no |
| A test line that went live | 9.6% | 71% | yes |
| A night with no line copy | 9.5% | 71% | yes |
| Times in the sender's offset | 10.0% | 72% | yes |
| A line whose agent changed | 8.6% | 71% | yes |
| A line gone from the list | 8.1% | 70% | yes |
| Unloaded near the 06:00 cutoff | 8.3% | 71% | yes |
| Line codes cased or padded | 8.1% | 71% | yes |
| Status casing and padding | 8.0% | 71% | yes |
| Local time with no zone | 14.0% | 83% | yes |
| The same day sent twice | 18.0% | 56% | no |
| Numbers with no check digit | 5.0% | 65% | no |
| UTC formatted 3 ways | 8.0% | 79% | yes |
| Blank refs holding text | 8.0% | 72% | yes |
| Epoch seconds as text | 10.0% | 83% | yes |
| 2 rates for the same day | 3.8% | 70% | yes |
| The same box on a second visit | 3.7% | 70% | yes |
| Days waived later | 3.5% | 70% | yes |
| Fixed by hand, same timestamp | 14.0% | 78% | yes |
| JSON cut short | 0.6% | 69% | yes |

### Why these happen

**Copied on several nights.** The copy job takes every visit that changed that day, so a visit appears once per night it changed or was charged. The table is a history of states, and the row billing wants is the last of them.

**Charged over several nights.** The terminal charges storage a day at a time, so a box's days land on several nights and each night's row holds only that night's days. The figure billing invoices is the total of them, which means every night has to be counted once: a night added twice overstates it and a night never read is simply missing.

**Loaded after the run started.** The copy job runs while the yard is quiet and the morning run starts at 03:00 UTC. A night the job ran long landed after the run had started, so that night's rows are first seen by the run after, under the earlier night's batch date. A pipeline that takes only tonight's date never sees them; one that takes whatever landed since its last run does.

**Newest row missing fields.** The gate app records the gate-out and saves the columns it owns, leaving the rest empty. The visit's newest row is then missing values an older row of the same visit still holds, and taking the newest row whole throws them away.

**The same row twice in a batch.** A night's load that dies partway is started again and writes its rows a second time. The 2 copies are identical but for the load time, so anything that adds the days up counts that night twice.

**NULL written as text.** A text dump has to write NULL somehow, and each export tool picks its own marker. Loaded into a text column the marker is a value like any other, so a box still in the yard looks gated out.

**Days charged after the close.** A box still in the yard when the days being closed end keeps being charged after them, so its last state and its total belong to later days than the ones billing is invoicing. A figure taken from the total instead of from the days the charges fell on counts them anyway.

**Old rows in a newer batch.** After a failed night, an extract of an old window is run again by hand and lands under a new batch. The newest batch then holds an older state of the visit, and load order stops meaning recency.

**The gate app's own state words.** The gate app was bought from another vendor and kept its own vocabulary: landed, on_hold, delivered, restowed. Both write to the same column and nobody mapped one onto the other.

**Box numbers spaced or cased.** A container number is painted on the box in groups, and people type it the way they read it: with spaces, with hyphens, in lower case. The number is the same; the text is not.

**A state that came days late.** A night the copy job ran long lands after the morning run, sometimes days after the state before it. The run that already wrote a figure for that visit wrote it from what it could see, and the row that changes it arrives later: a table that is only added to keeps the old figure, and only a run that goes back over the visits a late batch touched replaces it.

**A rate change during the stay.** A tariff changes while boxes sit in the yard: the days before its effective day are charged at the old rate and the days from it at the new. Pricing every day at the rate in force today, or at the first one the box was charged at, moves the bill by the difference.

**Line codes typed at the gate.** The gate app writes the line's code the way the trucker's booking carried it, lower-cased or padded. The line is the same, and an equality join no longer finds it.

**Camel-case JSON keys.** The truckers' booking portal serializes its fields in camel case. Its visits carry the same booking reference as every other, 1 key name away from where a reader looks.

**Visit keys with leading zeros.** One service writes the visit key the way its export pads it: to 10 digits with leading zeros, or with a space. The states of 1 visit then sit under 2 keys: a partition on the raw text splits it into 2 visits, each with part of the history and part of the days.

**A test line that went live.** A new line is onboarded as a test carrier while its EDI is proven, and the flag flips when it goes live. Its early copies still say test, so asking whether it was EVER a test line drops a real line's boxes.

**A night with no line copy.** The line copy failed on some nights and came back empty until the next one. A pipeline that reads the night's copy as the state of the lines that night finds none; one that keeps the night before, or checks the copy before it trusts it, knows better.

**Times in the sender's offset.** A line's own messages are relayed into the yard database in the zone of the office that sent them. As text, 03:30+05:30 sorts after 01:00+08 although it happened later, and its day is not the terminal day the box is billed on.

**A line whose agent changed.** A line is invoiced through its local agent, and lines change agents. The boxes that came off before the change are billed to the old party and the boxes after to the new, which only that night's copy holds, and only the latest copy is kept.

**A line gone from the list.** A line that merged into another is retired from the live table and is simply absent from every later copy, while its boxes are still in the yard. The night it was still there is the only night its row could be kept.

**Unloaded near the 06:00 cutoff.** The terminal's day is cut at the 06:00 shift change, so a box that came off at 07:00 terminal time belongs to that day although in UTC it is still the day before. The party it is billed to is the line's on the terminal day, and the calendar date in UTC picks the night before's copy.

**Line codes cased or padded.** The line's code was typed into the onboarding form for years before it became a picklist. The older lines carry whatever was typed, in whatever case.

**Status casing and padding.** The state is free text in the yard database, and 3 systems write it. Each cases and pads the word its own way, so the same state arrives under several spellings.

**Local time with no zone.** The oldest service keeps its times in a column with no zone and prints the clock on the wall at the port. Read as UTC it is 8 hours out, and 8 hours is enough to move a box onto the wrong terminal day.

**The same day sent twice.** Billing re-ran a terminal day for a box and sent that day again, marked for the day it belongs to. Both copies are in the table and the day's days were charged once, so the restated rows are the ones that count and the day has to be replaced rather than added.

**Numbers with no check digit.** One system keys a box on its owner code and serial and never stored the check digit, so its rows carry 10 characters. The standard says how the 11th is computed from the other 10.

**UTC formatted 3 ways.** The gate app formats a timestamp with its own library: a T and a Z, a full +00:00, fractional seconds. All of them are the same instant, and a text comparison or a fixed position treats them apart.

**Blank refs holding text.** A box with no booking gets whatever the gate form held: an empty string, a dash, N/A. Inside JSON those are values, and only the reader can decide that they mean nothing.

**Epoch seconds as text.** The crane telemetry stores time as a count of seconds since 1970, and its newer build as milliseconds. As text a count sorts before every date, so the row it stamps looks like the visit's oldest state however recent it is.

**2 rates for the same day.** A rate published wrong is published again in a later batch for the same effective day, and a history that keeps both rows has 2 for the day and tariff. A join returns both, and the earlier one is the wrong one.

**The same box on a second visit.** Containers circulate, and the same box comes through the terminal again within weeks. Its second visit is a new key with its own days; a pipeline that keys on the container number folds the 2 visits into 1 and bills the first visit for the second's days.

**Days waived later.** The commercial team waives days after a dispute, so a night's days can be negative. A total built from the days charged, or from the last night's row alone, is too high by them.

**Fixed by hand, same timestamp.** Operations releases a hold or re-nominates a box with a direct statement that bypasses the application, so the update time does not move. 2 rows then share a timestamp, and only the batch says which is later.

**JSON cut short.** The remarks column has a fixed width, and the load cuts what does not fit. What is left is not JSON, and a JSON function handed it raises and takes the whole task with it.

Concepts exercised: sqlAggregateOver, sqlBasicTypes, sqlBetween, sqlCaseWhen, sqlCast, sqlCoalesce, sqlConcat, sqlConditionalAgg, sqlCte, sqlDateAdd, sqlDateFormat, sqlDateTrunc, sqlDateVsTimestamp, sqlExtract, sqlGroupBy, sqlInList, sqlInnerJoin, sqlIsNull, sqlJsonExtract, sqlLagLead, sqlLeftJoin, sqlLength, sqlLimit, sqlLowerUpper, sqlMinMax, sqlMultipleJoins, sqlMultipleWindows, sqlNullif, sqlOperatorPrecedence, sqlPartitionBy, sqlReplace, sqlRowNumber, sqlSelectFrom, sqlSelfJoin, sqlStringBuilding, sqlSubqueryIn, sqlSubqueryScalar, sqlSubstring, sqlSumAvg, sqlTimestampType, sqlTrim, sqlWhere, sqlWindowDedup, sqlWindowFrame

## Submission

The DAG that was graded is in [`dag.sql`](./dag.sql).
