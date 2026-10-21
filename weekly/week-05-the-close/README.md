# Week 5: The Close

*A payments company is closing its books. The numbers come out of 30 nightly copies of its production database, and the landing does not keep them for long.*

[The Gauntlet on DataDriven](https://datadriven.io/community/week-5)

You're a data engineer at a card payments company. Every night, a job copies the day's changes from its database into 3 raw tables, which keep only recent copies. Finance is closing its books through 2026-10-12 and needs 1 clean row per payment. Write the DAG that builds that table from 2026-09-18 to 2026-10-17: it runs on the schedule you set, and each run sees only what the raw tables hold then.

## Result

| | |
|---|---|
| Score | 0.0000 |
| Rank | #11 of 13, top 85% |
| Points | +0 |
| Rows built | 0 of 99,261 |
| Work per raw row | .07x median |
| Run | crashed at task fct_payments |
| Statements | 4 |
| Scored | 2026-10-18 |

## Columns

| Column | Correct | Wrong | Missed |
|---|---:|---:|---:|
| `payment_id` | 0% | 0 | 99,261 |
| `status` | 0% | 0 | 99,261 |
| `amount_usd` | 0% | 0 | 99,261 |
| `settled_usd` | 0% | 0 | 99,261 |
| `settled_in_period_usd` | 0% | 0 | 99,261 |
| `captured_at` | 0% | 0 | 99,261 |
| `merchant_country` | 0% | 0 | 99,261 |
| `order_ref` | 0% | 0 | 98,665 |

## What the tables held

Every condition in the data, ordered by what it cost. "Handled" means its records came through about as well as the rest of the run.

| Condition | Of tables | Recovered | Handled |
|---|---:|---:|:---:|
| Copied on more than 1 night | 58.0% | 0% | no |
| Same row twice in 1 batch | 35.0% | 0% | no |
| Paid out over several nights | 34.2% | 0% | no |
| Landed after the run time | 31.1% | 0% | no |
| Created on a day with no rate | 25.0% | 0% | no |
| Last row lacks older fields | 45.0% | 0% | no |
| Money that moved after | 18.0% | 0% | no |
| NULL landed as text | 30.0% | 0% | no |
| Words of the other gateway | 16.0% | 0% | no |
| 0 and 3 decimal currencies | 13.6% | 0% | no |
| Ids that lost their zeros | 14.0% | 0% | no |
| Old rows in a newer batch | 25.0% | 0% | no |
| 2 rates for 1 day | 8.9% | 0% | no |
| Times in a local offset | 14.0% | 0% | no |
| More 0 and 3 place money | 12.8% | 0% | no |
| Major units, not minor | 15.0% | 0% | no |
| A state that came days late | 22.0% | 0% | no |
| Epoch time in a text field | 14.0% | 0% | no |
| A rate that came after the run | 10.7% | 0% | no |
| Fixed by hand, same stamp | 16.0% | 0% | no |
| Camel case key in the JSON | 12.0% | 0% | no |
| Country cased or padded | 7.9% | 0% | no |
| A night the copy never came | 9.6% | 0% | no |
| A day sent twice over | 18.0% | 0% | no |
| A seller that went live | 7.8% | 0% | no |
| A seller that moved | 9.2% | 0% | no |
| Money taken back later | 9.3% | 0% | no |
| Status casing and padding | 8.0% | 0% | no |
| UTC time, spelt 3 ways | 8.0% | 0% | no |
| A seller gone from the copy | 7.9% | 0% | no |
| Ids cased by 1 app | 5.0% | 0% | no |
| Blank refs that hold text | 8.0% | 0% | no |
| JSON cut at the field width | 0.6% | 0% | no |

### Why these happen

**Copied on more than 1 night.** The copy job takes every payment that changed that day, so a payment appears once per night it changed. The table is a history of states, and the row finance wants is the last of them.

**Same row twice in 1 batch.** A night's load that dies partway is started again and writes its rows a second time. The 2 copies are identical but for the load time, so anything keyed on the row's own values finds both.

**Paid out over several nights.** The processor pays a capture out in batches, so the money for 1 payment moves on several nights and each night's row holds only that night's movement. The figure finance closes on is the total of them, which means every night has to be counted once: a night added twice overstates it and a night never read is simply missing.

**Landed after the run time.** The copy job runs while production is quiet and the morning run starts at 03:00. A night the job ran long landed after the run had started, so that night's rows are first seen by the run after, under the earlier night's batch date. A pipeline that takes only tonight's date never sees them; one that takes whatever landed since its last run does.

**Created on a day with no rate.** Rates are published on business days and payments happen every day. A join on the date finds nothing for a Saturday, and the amount needs the last rate published before it.

**Last row lacks older fields.** The service that records a dispute or a capture saves the columns it owns and leaves the rest empty. The payment's newest row is then missing values an older row of the same payment still holds, and taking the newest row whole throws them away.

**Money that moved after.** A payment authorized on one of the last days being closed is captured after they close, so its last state is a capture and none of that money belongs to those days. A figure taken from the payment's final state instead of from the days the money moved counts it anyway.

**NULL landed as text.** A text dump has to write NULL somehow, and each export tool picks its own marker. Loaded into a text column the marker is a value like any other, so a missing time is no longer NULL.

**Words of the other gateway.** A second processor was added through an acquisition and kept its own vocabulary: authorised, refused, cancelled, chargeback. Both write to the same column and nobody mapped one onto the other.

**0 and 3 decimal currencies.** Minor units are not always hundredths. The yen has none and the Kuwaiti dinar has 3 decimals, so a division by 100 is right for most currencies and wrong by 100 or by 10 for these.

**Ids that lost their zeros.** One loader inferred a number from the id and dropped its letter and leading zeros; another lower-cased it. The merchant is the same, and an equality join no longer finds it.

**Old rows in a newer batch.** After a failed night, an extract of an old window is run again by hand and lands under a new batch. The newest batch then holds an older state of the payment, and load order stops meaning recency.

**2 rates for 1 day.** A rate published wrong is published again in a later batch, and a history that keeps both rows has 2 for the date and currency. A join returns both, and the earlier one is the wrong one.

**Times in a local offset.** A regional service writes times in its own offset. As text, 03:30+05:30 sorts after 01:00+00 although it happened earlier, and its calendar day is not the UTC day the rate is keyed by.

**More 0 and 3 place money.** ISO 4217 has more currencies that are not hundredths than the 2 everybody remembers: the won and the Chilean peso have no minor unit, and the Bahraini, Omani and Jordanian dinars have 3 decimals. A rule written for JPY and KWD alone is off by 100 or by 10 on these.

**Major units, not minor.** The amount column held decimal currency before it held minor units. Rows written by the old code path were never rewritten, so the same column carries 12.50 and 1250 for the same money.

**A state that came days late.** A night the copy job ran long lands after the morning run, sometimes days after the state before it. The run that already wrote a figure for that payment wrote it from what it could see, and the row that changes it arrives later: a table that is only added to keeps the old figure, and only a run that goes back over the payments a late batch touched replaces it.

**Epoch time in a text field.** The oldest service stores time as a count of seconds since 1970, and its newer build as milliseconds. As text a count sorts before every date, so the row it stamps looks like the payment's oldest state however recent it is.

**A rate that came after the run.** The rate feed runs long on some nights and lands after the morning run. A task that converts with whatever it can see that night has no rate for the day and writes nothing; the rate is there the night after, for a run that comes back to it.

**Fixed by hand, same stamp.** Operations corrects stuck payments with a direct statement that bypasses the application, so updated_at does not move. 2 rows then share a timestamp, and only the batch says which is later.

**Camel case key in the JSON.** The mobile client serializes its fields in camel case. Its payments carry the same order reference as every other, 1 key name away from where a reader looks.

**Country cased or padded.** Country was typed into an onboarding form for years before it became a picklist. The older merchants carry whatever was typed, in whatever case.

**A night the copy never came.** The merchant copy failed on some nights and the landing stayed empty until the next one came. A pipeline that reads the night's copy as the state of the merchants that night finds none; one that keeps the night before, or checks the copy before it trusts it, knows better.

**A day sent twice over.** The team upstream re-ran its extract for a day and sent that day again, marked for the day it belongs to. Both copies are in the table and the day's money moved once, so the restated rows are the ones that count and the day has to be replaced rather than added.

**A seller that went live.** A merchant integrates against production flagged as a test, then goes live and the flag flips. Its early snapshots still say test, so asking whether it was EVER a test merchant drops a real one.

**A seller that moved.** The merchants table is copied whole every night, so a merchant that moved is under one country on the nights before the move and the other after. Finance wants the country on the day of the payment, which only that night's copy holds, and the landing keeps only the latest.

**Money taken back later.** A dispute takes the money back, so a night's movement can be negative. A total built from what was paid out, or from the last night's row alone, is too high by it.

**Status casing and padding.** Status is free text in the source, and 3 services write it. Each cases and pads the word its own way, so the same state arrives under several spellings.

**UTC time, spelt 3 ways.** Each service formats a timestamp with its own library: a T and a Z, a full +00:00, fractional seconds. All of them are the same instant, and a text comparison or a fixed position treats them apart.

**A seller gone from the copy.** A merchant deleted from the source is simply absent from every later copy, and the landing holds only the latest. The night it was still there is the only night its row could be kept.

**Ids cased by 1 app.** One service writes the payment id the way its API received it, upper case or padded. The states of 1 payment then sit under 2 keys: a partition on the raw text splits it into 2 payments, each with part of the history.

**Blank refs that hold text.** A checkout with no order sends whatever its form held: an empty string, a dash, N/A. Inside JSON those are values, and only the reader can decide that they mean nothing.

**JSON cut at the field width.** The landing column for metadata has a fixed width, and the load cuts what does not fit. What is left is not JSON, and a JSON function handed it raises and takes the whole task with it.

Concepts exercised: sqlJsonExtract, sqlSelectFrom

## Submission

The DAG that was graded is in [`dag.sql`](./dag.sql).
