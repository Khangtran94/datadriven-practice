# Week 4 - The Interface

## 1) Raw input

The source is a JSON-lines log of HL7 v2.5.1 `ORU^R01` lab-result messages. Each message contains a result in HL7 segments; the log also includes multiple sender connections, acknowledgements and other non-result activity. Messages can be repeated or corrected, and some may be truncated. Documented wrapper fields include `received_at`, `connection`, and `message`.

**Sample size:** 10 input messages out of 1,000,000 log lines. The full stream has 1,000,000 lines.

Sample input messages: 10 rows (of 1,000,000 log lines). Optional wrapper fields are grouped under `other_fields`; HL7 segments are separated by line breaks.

| received_at | connection | message | other_fields |
| --- | --- | --- | --- |
| 2026-09-14T04:00:04Z | lis-results | <code>MSH&#124;^~\&amp;&#124;LIS&#124;HOSP&#124;ENGINE&#124;HOSP&#124;20260914000004-0400&#124;&#124;ORU^R01&#124;LIS0000000001&#124;P&#124;2.5.1</code><br><code>PID&#124;1&#124;&#124;10104553^^^HOSP^MR&#124;&#124;KIM^MINA&#124;&#124;19931116&#124;F</code><br><code>OBR&#124;1&#124;ORD00000001&#124;LAB0112472&#124;51990-0^Basic metabolic panel^LN&#124;&#124;&#124;20260913171353-0400</code><br><code>OBX&#124;1&#124;NM&#124;2160-0^Creatinine^LN&#124;&#124;3.24&#124;mg/dL&#124;0.6-1.2&#124;H&#124;&#124;&#124;F</code> | NULL |
| 2026-09-14T04:00:12Z | lis-results | <code>MSH&#124;^~\&amp;&#124;LIS&#124;HOSP&#124;ENGINE&#124;HOSP&#124;20260914000012-0400&#124;&#124;ORU^R01&#124;LIS0000000003&#124;P&#124;2.5.1</code><br><code>PID&#124;1&#124;&#124;10104553^^^HOSP^MR&#124;&#124;KIM^MINA&#124;&#124;19931116&#124;F</code><br><code>PV1&#124;1&#124;E&#124;4N^08^A</code><br><code>OBR&#124;1&#124;ORD00000003&#124;LAB0128310&#124;51990-0^Basic metabolic panel^LN&#124;&#124;&#124;20260913173514-0400</code><br><code>OBX&#124;1&#124;NM&#124;2160-0^Creatinine^LN&#124;&#124;0.80&#124;mg/dL&#124;0.6-1.2&#124;&#124;&#124;&#124;F</code><br><code>ZLB&#124;analyzer=cobas-8000&#124;run=4930</code> | NULL |
| 2026-09-14T04:00:42Z | reflab-results | <code>MSH&#124;^~\&amp;&#124;REFLAB&#124;RLAB&#124;ENGINE&#124;HOSP&#124;20260913230042-0500&#124;&#124;ORU^R01&#124;RL0000000001&#124;P&#124;2.3</code><br><code>PID&#124;1&#124;&#124;10112472^^^HOSP^MR&#124;&#124;REYES^KAREN&#124;&#124;19321007&#124;M</code><br><code>OBR&#124;1&#124;ORD00000009&#124;RL0175824&#124;CBC^CBC panel^L&#124;&#124;&#124;20260913181611-0500</code><br><code>OBX&#124;1&#124;NM&#124;HGB^Hemoglobin^L&#124;&#124;15.0&#124;g/dL&#124;12.0-16.0&#124;&#124;&#124;&#124;F</code> | NULL |
| 2026-09-14T04:01:04Z | lis-results | <code>MSH&#124;^~\&amp;&#124;LIS&#124;HOSP&#124;ENGINE&#124;HOSP&#124;20260914000104-0400&#124;&#124;ORU^R01&#124;LIS0000000017&#124;P&#124;2.5.1</code><br><code>PID&#124;1&#124;&#124;10104553^^^HOSP^MR&#124;&#124;KIM^MINA&#124;&#124;19931116&#124;F</code><br><code>OBR&#124;1&#124;ORD00000004&#124;  LAB0136229&#124;58410-2^CBC panel^LN&#124;&#124;&#124;20260913195250-0400</code><br><code>OBX&#124;1&#124;NM&#124;6690-2^WBC^LN&#124;&#124;7.5&#124;10*3/uL&#124;4.0-11.0&#124;&#124;&#124;&#124;F</code> | NULL |
| 2026-09-14T04:01:11Z | lis-results | <code>MSH&#124;^~\&amp;&#124;LIS&#124;HOSP&#124;ENGINE&#124;HOSP&#124;20260914000111-0400&#124;&#124;ORU^R01&#124;LIS0000000019&#124;P&#124;2.5.1</code><br><code>PID&#124;1&#124;&#124;10136229^^^HOSP^MR &#124;&#124;KOWALSKI^DAVID^K&#124;&#124;19710515&#124;M</code><br><code>OBR&#124;1&#124;ORD00000014&#124;  LAB0215419&#124;51990-0^Basic metabolic panel^LN&#124;&#124;&#124;20260913184556-0400</code><br><code>OBX&#124;1&#124;NM&#124;2951-2^Sodium^LN&#124;&#124;141&#124;mmol/L&#124;136-145&#124;&#124;&#124;&#124;F</code> | {"direction":"in"} |
| 2026-09-14T04:01:15Z | lis-results | <code>MSH&#124;^~\&amp;&#124;LIS&#124;HOSP&#124;ENGINE&#124;HOSP&#124;20260914000115-0400&#124;&#124;ORU^R01&#124;LIS0000000020&#124;P&#124;2.5.1</code><br><code>PID&#124;1&#124;&#124;10112472^^^HOSP^MR&#124;&#124;REYES^KAREN&#124;&#124;19321007&#124;M</code><br><code>ORC&#124;RE&#124;ORD00000015&#124;LAB0223338</code><br><code>OBR&#124;1&#124;ORD00000015&#124;LAB0223338&#124;51990-0^Basic metabolic panel^LN&#124;&#124;&#124;20260913184032-0400</code><br><code>OBX&#124;1&#124;NM&#124;2951-2^Sodium^LN&#124;&#124;141&#124;mmol/L&#124;136-145&#124;&#124;&#124;&#124;F</code> | {"ack":"sent","_seq":41937628} |
| 2026-09-14T04:01:31Z | reflab-results | <code>MSH&#124;^~\&amp;&#124;REFLAB&#124;RLAB&#124;ENGINE&#124;HOSP&#124;20260913230131-0500&#124;&#124;ORU^R01&#124;RL0000000003&#124;P&#124;2.3</code><br><code>PID&#124;1&#124;&#124;10128310^^^HOSP^MR&#124;&#124;BERG^ROBERT&#124;&#124;19320303&#124;F</code><br><code>OBR&#124;1&#124;ORD00000018&#124;RL0247095&#124;BMP^Basic metabolic panel^L&#124;&#124;&#124;20260913164914-0500</code><br><code>OBX&#124;1&#124;NM&#124;GLU^Glucose^L&#124;&#124;86&#124;mg/dL&#124;70-99&#124;&#124;&#124;&#124;F</code> | NULL |
| 2026-09-14T04:01:39Z | reflab-results | <code>MSH&#124;^~\&amp;&#124;REFLAB&#124;RLAB&#124;ENGINE&#124;HOSP&#124;20260913230139-0500&#124;&#124;ORU^R01&#124;RL0000000004&#124;P&#124;2.3</code><br><code>PID&#124;1&#124;&#124;10128310^^^HOSP^MR&#124;&#124;BERG^ROBERT&#124;&#124;19320303&#124;F</code><br><code>OBR&#124;1&#124;ORD00000018&#124;RL0247095&#124;BMP^Basic metabolic panel^L&#124;&#124;&#124;20260913164914-0500</code><br><code>OBX&#124;1&#124;NM&#124;CREAT^Creatinine^L&#124;&#124;0.84&#124;mg/dL&#124;0.6-1.2&#124;&#124;&#124;&#124;F&#124;&#124;&#124;20260913164914-0500</code> | NULL |
| 2026-09-14T04:02:02Z | lis-results | <code>MSH&#124;^~\&amp;&#124;LIS&#124;HOSP&#124;ENGINE&#124;HOSP&#124;20260914000202-0400&#124;&#124;ORU^R01&#124;LIS0000000032&#124;P&#124;2.5.1</code><br><code>PID&#124;1&#124;&#124;10104553^^^HOSP^MR&#124;&#124;KIM^MINA&#124;&#124;19931116&#124;F</code><br><code>OBR&#124;1&#124;ORD00000003&#124;LAB0128310&#124;51990-0^Basic metabolic panel^LN&#124;&#124;&#124;20260913173514-0400</code><br><code>OBX&#124;1&#124;NM&#124;2951-2^Sodium^LN&#124;&#124; 139&#124;mmol/L&#124;136-145&#124;&#124;&#124;&#124;F&#124;&#124;&#124;20260913173514-0400</code><br><code>NTE&#124;1&#124;L&#124;Hemolyzed specimen</code><br><code>ZLB&#124;analyzer=XN-1000&#124;run=9474</code> | NULL |
| 2026-09-14T04:02:04Z | lis-results | <code>MSH&#124;^~\&amp;&#124;LIS&#124;HOSP&#124;ENGINE&#124;HOSP&#124;20260914000204-0400&#124;&#124;ORU^R01&#124;LIS0000000033&#124;P&#124;2.5.1</code><br><code>PID&#124;1&#124;&#124;10104553^^^HOSP^MR&#124;&#124;KIM^MINA&#124;&#124;19931116&#124;F</code><br><code>OBR&#124;1&#124;ORD00000020&#124;LAB0262933&#124;51990-0^Basic metabolic panel^LN&#124;&#124;&#124;20260913220439-0400</code><br><code>OBX&#124;1&#124;NM&#124;2823-3^Potassium^LN&#124;&#124;3.8&#124;mmol/L&#124;3.5-5.1&#124;&#124;&#124;&#124;F</code> | NULL |

## 2) Target table

Produce one normalized row per accession and test with exactly:

| Column | Requirement |
|---|---|
| `accession` | Uppercase, trimmed accession key |
| `test` | Canonical supported test name or null |
| `patient_id` | Hospital MR number or null |
| `value` | Reported value as a two-decimal string or null |
| `unit` | Normalized UCUM unit or null |
| `observed_at` | Specimen collection timestamp in UTC or null |
| `status` | `final`, `preliminary`, `corrected`, or null |

Sample expected target rows: 10 results.

| accession | test | patient_id | value | unit | observed_at | status |
| --- | --- | --- | --- | --- | --- | --- |
| LAB0112472 | creatinine | 10104553 | 3.24 | mg/dL | 2026-09-13T21:13:53Z | final |
| LAB0128310 | creatinine | 10104553 | 0.80 | mg/dL | 2026-09-13T21:35:14Z | final |
| RL0175824 | hemoglobin | 10112472 | 15.00 | g/dL | 2026-09-13T23:16:11Z | final |
| LAB0136229 | wbc | 10104553 | 7.50 | 10*3/uL | 2026-09-13T23:52:50Z | final |
| LAB0215419 | sodium | 10136229 | 141.00 | mmol/L | 2026-09-13T22:45:56Z | final |
| LAB0223338 | sodium | 10112472 | 141.00 | mmol/L | 2026-09-13T22:40:32Z | final |
| RL0247095 | glucose | 10128310 | 86.00 | mg/dL | 2026-09-13T21:49:14Z | final |
| RL0247095 | creatinine | 10128310 | 0.84 | mg/dL | 2026-09-13T21:49:14Z | final |
| LAB0128310 | sodium | 10104553 | 139.00 | mmol/L | 2026-09-13T21:35:14Z | final |
| LAB0262933 | potassium | 10104553 | 3.80 | mmol/L | 2026-09-14T02:04:39Z | final |

## 3) Notes from the quality team

- For the same result, corrected outranks final; final outranks an erroneous (`W`) result; erroneous outranks preliminary.
- A timestamp without an offset is the sender's local time.
- The hospital uses US Eastern time; the reference lab uses US Central time.
- Ignore `received_at`, `connection`, and other engine metadata.
- Two layers write the log in turn, escaping the message content.

## 4) Expected sample output

The sample includes **10 input messages** and **10 expected result rows**; the expected rows are shown under the target table.

## 5) Execution schedule

This is a streaming handler challenge, not a calendar-based DAG. `Handler.process(raw)` receives each of 1,000,000 lines in order; `Handler.finalize()` can emit remaining rows. Use Python 3.12 and only the documented standard-library imports. The stream has a 512 MB memory budget and a 10-minute runtime cap.
