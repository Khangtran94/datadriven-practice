# Week 8: The Auction

*A search engine sells the few ad slots on every page of results, one auction per search. The advertiser pays only when someone clicks.*

[The Gauntlet on DataDriven](https://datadriven.io/community/week-8)

You're a data engineer at a search engine that shows a few ads above and below its results, each slot sold at auction the moment someone searches. Advertisers pay only for clicks, and the inventory team, which sells that ad space, needs 1 clean row per ad shown: whose it was, where it sat, and what it billed. Each night, a job copies 2 raw tables out of 2 systems. The ad server provides ad_events, a log with a row for every ad shown, every click on one, and every verdict its click-fraud filter reached about a click. Billing provides accounts, a nightly snapshot of the advertiser accounts that are open. Write the DAG that builds the inventory team's table of ads shown from 2026-10-09 to 2026-11-07; billing's month ended 2026-10-31.

## Result

| | |
|---|---|
| Score | 0.8416 |
| Rank | #3 of 8, top 38% |
| Points | +120 |
| Rows built | 157,679 of 170,216 |
| Work per raw row | 1.7x median |
| Statements | 5 |
| Scored | 2026-11-08 |

9,254 rows matched no record. Together they cost 18,508 points.

## Columns

| Column | Correct | Wrong | Missed |
|---|---:|---:|---:|
| `served_at` | 83% | 63 | 28,557 |
| `served_date` | 83% | 41 | 28,557 |
| `billed_micros` | 85% | 12,859 | 12,537 |
| `slot` | 87% | 0 | 22,626 |
| `clicked` | 88% | 7,192 | 12,537 |
| `impression_id` | 93% | 0 | 12,537 |
| `customer_id` | 93% | 0 | 12,537 |

## What the tables held

Every condition in the data, ordered by what it cost. "Handled" means its records came through about as well as the rest of the run.

| Condition | Of tables | Recovered | Handled |
|---|---:|---:|:---:|
| Ids with = padding on the end | 5.0% | 0% | no |
| Times in 3 other forms | 18.0% | 77% | no |
| An ad someone clicked | 19.7% | 81% | no |
| Events in their writer's words | 16.0% | 63% | no |
| Slots named the old way | 14.0% | 82% | no |
| The account's day, not UTC's | 20.0% | 88% | yes |
| Copied after the run began | 17.4% | 87% | yes |
| The same row twice in a file | 16.0% | 87% | yes |
| Account ids with dashes | 14.0% | 88% | yes |
| No account table that run | 13.4% | 88% | yes |
| Click ids encoded for a URL | 45.0% | 65% | no |
| Prices in units of money | 30.0% | 75% | no |
| A day's rows sent again | 8.0% | 83% | no |
| NULL written as text | 50.0% | 81% | no |
| Asia's file after the run | 7.8% | 87% | yes |
| A second click, on a sitelink | 3.1% | 80% | no |
| An account that left mid-month | 5.0% | 88% | yes |
| A click a day ahead of its ad | 4.0% | 87% | yes |
| An account id short of its 0 | 60.0% | 87% | yes |
| A verdict after the log forgot | 2.4% | 82% | no |
| An account opened mid-month | 3.6% | 88% | yes |
| A click the filter ruled out | 2.7% | 84% | yes |
| A repeat click priced 0 | 1.4% | 80% | no |
| Flagged, then cleared | 1.0% | 79% | no |
| A third click on 1 ad | 0.9% | 80% | no |
| A clock change mid-month | 1.2% | 87% | yes |
| A click refused on the spot | 1.0% | 85% | yes |
| Credited the month after | 0.4% | 74% | no |
| An old verdict sent again | 60.0% | 79% | no |
| An account that moved east | 0.7% | 87% | yes |

### Why these happen

**Ids with = padding on the end.** 16 bytes in base64 is 22 characters and 2 = signs of padding that carry nothing. The serving build drops them; the older one keeps them, so the same impression is 2 keys unless the padding comes off.

**Times in 3 other forms.** The serving build counts microseconds; the click server counts milliseconds; the fraud filter writes ISO text, and its older build writes California time with the day's offset. As text the forms sort in no useful order, so the first click and the last verdict are picked wrong.

**An ad someone clicked.** An impression and its click are separate rows written by separate programs, often in separate files when the click comes after midnight. The row the inventory team wants is the ad, with its click settled onto it.

**Events in their writer's words.** 3 programs write the log: the serving build calls a serve an impression, the click server shouts CLICK, the fraud filter writes IVT for invalid traffic and reinstated for a click it cleared. The column is free text and nobody mapped one vocabulary onto another.

**Slots named the old way.** Search ads used to run down the side of the page too, and the serving code named the block above the results the mainline to tell it apart. The older build still writes ML2 or mainline-2 for the second ad from the top, and B1 for the first one below the results.

**The account's day, not UTC's.** An advertiser's budget, reports and invoice run on the account's own time zone, set when the account was opened. An evening ad in California is the next morning in UTC.

**Copied after the run began.** The morning copy starts after the last of the day's files closes, and on some mornings it starts hours late. That day's rows are first seen by the run after, under a stamp newer than any the run has read; a pipeline that takes only the night's own day never sees them.

**The same row twice in a file.** The copy job retries a transfer it thinks has failed, and the file it already loaded is loaded again: the same row, the same stamp.

**Account ids with dashes.** The older serving build writes the account the way an advertiser sees it on screen, 3 digits, 3 digits, 4 digits with dashes between. The account is the same; the text is not, and a join to billing's table on the raw text finds nothing.

**No account table that run.** On a few mornings billing's copy arrived after the run or never came, and on the last morning it never came at all, so the run that wrote the final table found no accounts. A pipeline that read only the latest copy had no time zone for anyone; one that kept the copies it had seen did.

**Click ids encoded for a URL.** A click arrives through the ad's link, and a URL cannot carry + or / as they are: the click server writes the impression id in base64url (- and _) or percent-encoded (%2B, %2F). The bytes are the same id; as text it matches no serve.

**Prices in units of money.** Ad prices are kept in micros so that no currency needs a fraction: 850000 is 85 cents. The legacy click path logs the price the way an invoice prints it, 0.85, or 45 for a yen account, and a micros column read as is bills a millionth of the price.

**A day's rows sent again.** When a morning's load fails part way, the day is copied again by hand, and every row of it arrives a second time under a later morning's stamp. The rows are the same events; the stamp says nothing about when they happened.

**NULL written as text.** A text log has to write NULL somehow, and each writer picks its own marker. Loaded into a text column the marker is a value like any other, so a click with no account looks like it had one.

**Asia's file after the run.** The copy job stamps every file of a morning with the time it began, and the 3 serving data centers' files arrive in turn, Asia's last. On a morning the job began late enough, Asia's rows arrive after the run with a stamp the run already read past: a watermark that takes only stamps newer than the last it saw never comes back for them, and a lookback, a merge over the whole window or a sensor does.

**A second click, on a sitelink.** A search ad carries sitelinks, small links to other pages of the advertiser's site, and a searcher who clicks the headline and comes back can click a sitelink of the same ad. Each click costs the same, and the ad is charged for up to 2 clicks per impression.

**An account that left mid-month.** Billing's table holds the accounts that are open, and the morning copy takes it as it stands. An account that closes is gone from every later copy, and its earlier ads still need its time zone.

**A click a day ahead of its ad.** A serving cluster that falls behind ships an hour of its log with the next day's file, while the click server, which logs clicks on its own, is on time. The click is in the table a night before the ad it was a click on, and a pipeline that only ever joins a night's clicks to the same night's ads drops it.

**An account id short of its 0.** An account id is 10 digits and some begin with 0. The newer serving build stores it as a number, and a number has no leading zero, so the id arrives 9 digits long and matches no account.

**A verdict after the log forgot.** The fraud filter keeps reviewing a click for up to a week, and the log keeps only a few days. A verdict that lands after the click has gone from the table changes a row the pipeline already wrote, and only a pipeline that kept the click can still apply it.

**An account opened mid-month.** A new advertiser can serve the hour the account is opened. It is in billing's copies only from the next morning on, and never in the copies before.

**A click the filter ruled out.** The fraud filter reviews clicks after they happen, looking for robots, click farms and an advertiser's rivals. An invalid click is not billed: the advertiser pays nothing for it.

**A repeat click priced 0.** A searcher double-clicks, and the click server logs both clicks. It filters a rapid repeat on the spot as a duplicate and logs it at a price of 0: the ad was clicked once, and billed once.

**Flagged, then cleared.** An advertiser disputes a verdict, or a newer model reviews the click again and finds a person behind it. The filter sends a second verdict, and the latest one by its own time is the one billing acts on.

**A third click on 1 ad.** The search engine charges an ad for at most 2 clicks per impression, however many links on it the searcher follows. A third click is logged at its price like the others and is never billed.

**A clock change mid-month.** Europe's clocks go back on the last Sunday of October and the Americas' a week later, and Sydney's and Auckland's went forward weeks before. A zone is an offset only until its next change: a fixed offset per account puts an ad near midnight on the wrong day for one side of it.

**A click refused on the spot.** The click server drops the plainest robots before billing ever sees them and logs the click at a price of 0. The click happened, so the ad was clicked; nothing was billed for it.

**Credited the month after.** Billing closes a month and sends the invoice. The fraud filter keeps reviewing clicks, and a click it rules out after the close stays on the invoice for the month it happened; the money comes back as a credit on the next one. The verdict that counts for the click is the last one reached before its month closed, on the account's own calendar.

**An old verdict sent again.** The fraud filter reprocesses a day when its model is updated, and sends the verdicts it reached for that day again. A click it later cleared gets its first verdict a second time, after the one that replaced it: the newest row says invalid, the newest verdict says valid.

**An account that moved east.** An advertiser that moves its marketing team can move the account's time zone, east only and once. Reports keep the old zone for the days before the change. Billing's copy only ever shows the zone as it stands, so only a pipeline that kept every copy knows which zone was in force on the day an ad was shown.

Concepts exercised: sqlBasicTypes, sqlCaseWhen, sqlCast, sqlCoalesce, sqlConcat, sqlConditionalAgg, sqlCte, sqlDateFormat, sqlDateTrunc, sqlDateVsTimestamp, sqlDistinct, sqlExtract, sqlGroupBy, sqlInList, sqlInnerJoin, sqlIsNull, sqlLagLead, sqlLeftJoin, sqlLength, sqlLimit, sqlLowerUpper, sqlMinMax, sqlMultipleJoins, sqlMultipleWindows, sqlOperatorPrecedence, sqlPartitionBy, sqlRegexMatch, sqlReplace, sqlRowNumber, sqlSelectFrom, sqlSelfJoin, sqlStringBuilding, sqlSubqueryIn, sqlSubqueryScalar, sqlSubstring, sqlSumAvg, sqlTimestampType, sqlTrim, sqlWhere, sqlWindowDedup

## Submission

The DAG that was graded is in [`dag.sql`](./dag.sql).
