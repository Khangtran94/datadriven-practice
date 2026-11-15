# Week 9: The Basket

*A shopper walks the store with your grocery order, scanning each item into the bags. Finance needs to know what every basket cost.*

[The Gauntlet on DataDriven](https://datadriven.io/community/week-9)

You're a data engineer at a grocery delivery app. A customer orders from a store's shelves in the app, a shopper walks the aisles picking each item and scanning it into the bags, and a driver brings them to the door. Finance needs 1 clean row per order: whether it was delivered, how many items it charged, what they cost, and the tip. The order service provides order_events, a live table with a row each time an order is placed, changed or delivered. The shopper app provides scans, a log with a row for every item scanned into an order. The merchandising system provides prices, a nightly snapshot of the stores' price list. Write the DAG that builds finance's table of the orders placed from 2026-10-16 to 2026-11-14.

## Result

| | |
|---|---|
| Score | 0.6682 |
| Rank | #2 of 5, top 40% |
| Points | +150 |
| Rows built | 17,036 of 17,036 |
| Work per raw row | 2.1x median |
| Statements | 7 |
| Scored | 2026-11-15 |

## Columns

| Column | Correct | Wrong | Missed |
|---|---:|---:|---:|
| `subtotal` | 38% | 10,612 | 0 |
| `items` | 78% | 3,696 | 0 |
| `tip` | 87% | 2,153 | 0 |
| `delivered_at` | 94% | 0 | 950 |
| `status` | 100% | 20 | 0 |
| `order_id` | 100% | 0 | 0 |

## What the tables held

Every condition in the data, ordered by what it cost. "Handled" means its records came through about as well as the rest of the run.

| Condition | Of tables | Recovered | Handled |
|---|---:|---:|:---:|
| An item sold by the pound | 91.1% | 82% | no |
| A price changed since ordered | 78.4% | 81% | no |
| Events deleted before a run | 62.1% | 83% | yes |
| Scanned on the newer app | 60.5% | 84% | yes |
| A 2 for $5 offer | 24.8% | 76% | no |
| A label printed at the deli | 32.0% | 82% | yes |
| UPCs with a 0 in front | 70.0% | 77% | no |
| A day sent again whole | 29.2% | 81% | yes |
| Times in 2 other forms | 26.0% | 82% | yes |
| Tips with $ or USD | 15.0% | 71% | no |
| A unit taken back out | 11.5% | 63% | no |
| A scale that reads in ounces | 15.9% | 76% | no |
| A tip changed after delivery | 18.6% | 82% | yes |
| NULL written as text | 45.0% | 80% | yes |
| Each app's own words | 18.0% | 75% | no |
| Order numbers typed with # | 9.0% | 65% | no |
| Copied after the run began | 15.5% | 82% | yes |
| An item no longer sold | 12.7% | 80% | yes |
| Saved on the phone for hours | 13.3% | 82% | yes |
| The same scan twice in a file | 10.0% | 82% | yes |
| A replacement turned down | 8.2% | 81% | yes |
| A scan the store took out | 2.8% | 64% | no |
| A tip change synced late | 5.4% | 81% | yes |
| Ordered ahead of a new price | 4.8% | 79% | yes |
| A shelf find priced days later | 4.6% | 82% | yes |
| Refused, then taken after all | 3.5% | 81% | yes |
| A day with no price list | 3.2% | 80% | yes |
| An order brought back | 2.1% | 79% | yes |
| A cancelled order | 5.9% | 100% | yes |
| Picked, then called off | 3.7% | 100% | yes |

### Why these happen

**An item sold by the pound.** Bananas, apples and the deli's olives are sold by weight: the line is the weight times the price per pound, rounded to the cent, and it is 1 item however much it weighs.

**A price changed since ordered.** Prices change overnight for the week's offers, and the price list shows only today's. The price an order paid is in the copy that was current when it was placed, which only a pipeline that kept every copy still has.

**Events deleted before a run.** The order service keeps its events for 6 hours and then deletes them, the way a live table with a time to live does. A run at dawn sees the evening's last hours; the rest of the day's events are gone before it starts, and only a pipeline that reads the table at least every 6 hours holds every event of the day.

**Scanned on the newer app.** The newer release of the shopper app sends the scale's reading in its own field and a quantity of 1, and the copy job added weight_lb to the table when the first file carried it. Shoppers update when they choose, so both releases write the same table all month.

**A 2 for $5 offer.** A store runs an offer the way its shelf tag prints it: 2/5.00, or 2 for 5.00 on the older pricing screen, which is 2.50 each. The price list carries the tag's text, and digits taken out of it read 25.00.

**A label printed at the deli.** The deli, meat and cheese counters weigh what they sell and print a label: a barcode starting with 2 that carries the item and its price in cents. It is on no price list, and a join to one finds nothing for it.

**UPCs with a 0 in front.** A UPC is 12 digits, and the same barcode read as an EAN-13, the international form, is 13: a 0 in front. The older release's scanner library reports every UPC that way, so its scans match no item on the price list, and a store label read the same way no longer starts with 2.

**A day sent again whole.** Each night the stores check the day's scans against the register, and when a store finds a mistake the whole day is sent again a morning or 2 later. Every scan of the day arrives a second time under a new stamp.

**Times in 2 other forms.** The driver app counts milliseconds since 1970; the customer app writes the phone's own clock with its offset from UTC. As text the forms sort in no useful order, and the latest tip by the text of its time is not the latest tip.

**Tips with $ or USD.** The web checkout writes a tip the way the page shows it, with its dollar sign; the support tool writes the currency after the amount. A number read from the text as it stands is no number.

**A unit taken back out.** A shopper who scans 1 unit too many takes it back in the app, and the app records that as a scan of -1. The item's quantity is the sum of its scans.

**A scale that reads in ounces.** Some stores' scales report in ounces, and the newer app passes the reading on with its unit, 20.32 oz, in a field named for pounds. 16 ounces are a pound; the number alone is 16 times the weight.

**A tip changed after delivery.** A customer can change the tip for 3 days after the bags arrive. Each change is a new event, and the last one set is what the shopper is paid.

**NULL written as text.** The older app sends no weight_lb at all, and the copy job writes the missing value its own way: NULL as a word, null, or nothing. In a text column each is a value like any other, so a weight read from it first is a weight of nothing.

**Each app's own words.** The order service stores what each client sends. The driver app reports DELIVERED or dropoff_complete, the customer app tip_updated or sub_rejected, and the support tool spells canceled the American way. Nobody mapped one vocabulary onto another.

**Order numbers typed with #.** A shopper scans the barcode on the order card to start picking, and when a crumpled card will not scan they type the number in as it is printed, # and all. The order is the same; as text it matches nothing the order service wrote.

**Copied after the run began.** The copy job starts after the day's file closes, and on some mornings it starts hours late. That day's scans are first seen by the run after, under a stamp newer than any the run has read, and a pipeline that reads only the night's own day never sees them.

**An item no longer sold.** An item the stores stop selling leaves the price list, and every copy after that leaves it out. The orders that bought it before still need its price.

**Saved on the phone for hours.** The driver app saves a delivery on the phone until it has signal again, and sends it with the moment the bags were left. The order service writes the row when it arrives: the row's own time is when it was written, not when the order was delivered.

**The same scan twice in a file.** The copy job retries a file transfer it thinks has failed, and the file it already loaded is loaded again: the same row, the same stamp.

**A replacement turned down.** When an item is out of stock the shopper scans a replacement and the customer can turn it down in the app. The scan stays in the shopper app's file; the refusal is an event in the order service, and only the 2 together say what was charged.

**A scan the store took out.** A scan the register never charged (an item scanned and then left behind) is not in the day's second file. Nothing says it was removed: it is simply not there, so a pipeline that merges the second file into the first by scan keeps it, and one that replaces the day does not.

**A tip change synced late.** A customer changes the tip on the phone with no signal and again on the website, which is written at once. The phone's change arrives later still. The tip the customer set last is the web's, by when each was set, and the last row written is the phone's.

**Ordered ahead of a new price.** The new prices take effect when the morning's price list is published. An order placed after midnight and before it pays the night before's price, so a join on the calendar day prices it a day early.

**A shelf find priced days later.** A shopper who cannot find an item may take a replacement from the shelf that the app does not list yet; the merchandising team adds it to the price list a few days later, and its first price is the one charged.

**Refused, then taken after all.** A customer can turn a replacement down in the app and then accept it after all, in the chat with the shopper. Each reply is an event naming the scan, and the last one counts.

**A day with no price list.** On 1 morning the price list's copy never came. The prices in force that day were the night before's, and a pipeline that looks only for the day's own copy finds none.

**An order brought back.** A customer who cancels by mistake calls support, and support brings the order back: a reinstated event after the cancel. The shopper picks it and the driver delivers it like any other order.

**A cancelled order.** A customer can cancel until the driver leaves the store. A cancelled order is charged nothing.

**Picked, then called off.** An order cancelled while the shopper is at the till still has every scan in the shopper app's file; the items go back on the shelf and nothing is charged.

Concepts exercised: sqlAggregateOver, sqlBasicTypes, sqlCaseWhen, sqlCast, sqlCoalesce, sqlConcat, sqlCte, sqlDateFormat, sqlDateTrunc, sqlDecimalType, sqlExtract, sqlGroupBy, sqlInList, sqlInnerJoin, sqlIsNull, sqlLagLead, sqlLeftJoin, sqlLength, sqlLimit, sqlLowerUpper, sqlMinMax, sqlMultipleJoins, sqlMultipleWindows, sqlNullif, sqlOperatorPrecedence, sqlPartitionBy, sqlRegexMatch, sqlReplace, sqlRowNumber, sqlSelectFrom, sqlSelfJoin, sqlStringBuilding, sqlSubqueryIn, sqlSubqueryScalar, sqlSubstring, sqlSumAvg, sqlTimestampType, sqlTrim, sqlWhere, sqlWindowDedup

## Submission

The DAG that was graded is in [`dag.sql`](./dag.sql).
