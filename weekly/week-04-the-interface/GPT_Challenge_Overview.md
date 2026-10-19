# Week 4: The Interface — Challenge Overview

## 1. Challenge at a Glance
Extract one clean row per usable laboratory result from JSON-logged HL7 v2 messages without losing clinical meaning across segments, identifiers, units, timestamps, and revisions.
- **Input:** JSON-wrapped HL7 messages, possibly with batch framing, MLLP characters, and escaped line endings.
- **Output grain:** one row per canonical laboratory result.
- **Fields:** `accession`, `test`, `patient_id`, `value`, `observed_at`, `unit`, `status`.
- **Core techniques:** protocol-aware parsing, authority-aware identity, clinical normalization, temporal precedence, and lifecycle handling.

## 2. Domain Knowledge
HL7 v2 is a structured healthcare messaging standard. MSH contains message context and delimiters; PID carries patient identifiers; SPM describes specimens; OBR carries order context; OBX carries observations; MRG can describe identifier merges. An accession identifies an order/specimen and is not automatically a patient ID. MRNs depend on their issuing authority. LOINC is a standardized observation code system. Preliminary, final, corrected, and withdrawn results are lifecycle states. Collection/observation time is not necessarily receipt time or analyzer run time.

## 3. Business Rules and Output Contract
Decode JSON and HL7 escaping in the correct layers. Handle MLLP framing and batch headers/trailers. Split segments using supported terminators and parse fields/components/repetitions using message-declared delimiters. Select the relevant result-bearing OBX. Resolve patient ID using identifier type and assigning authority; resolve accession from OBR-3. Normalize test code, value, unit, status, and observation/collection time using explicit precedence. Preserve meaningful comparator symbols and flags. Apply correction, finalization, and withdrawal semantics. Deduplicate by canonical result identity rather than only by message control ID.

## 4. Difficulty Assessment
**Advanced domain-specific integration.** String operations are manageable; protocol semantics are hard. Repeated segments, identifiers from different authorities, multiple time fields, unit systems, and result lifecycle events can make a plausible-looking extraction clinically wrong.

## 5. Estimated Experience Equivalence
These are heuristic learning references, not validated hiring benchmarks or a measure of an individual's overall competence.

| Skill | Approximate experience equivalent | Rationale |
|---|---|---|
| Structured message parsing | 1–3 years | JSON escaping, delimiters, segments, repetitions |
| HL7 v2 interoperability | 2–5 years | Segment semantics, codes, and identifiers |
| Clinical data quality and time semantics | 2–5 years | Units, collection time, corrections, withdrawals |
| Identity resolution and deduplication | 2–4 years | Assigning authorities, merges, retries |

**Challenge-level estimate: roughly 3–5 years of relevant data integration experience**, especially if HL7 is new to the solver. The README defines requirements; `handler.py` defines the interface; `gold_submit.py` illustrates one possible approach. The estimate does not describe the user's personal level, and the reference is not a universal seniority benchmark.

## 6. Core Engineering Patterns
- Layered decoding: transport framing, JSON escaping, HL7 framing, segments, fields, components, and repetitions.
- Use delimiters declared in MSH instead of assuming all senders are identical.
- Resolve patient identity using identifier type and assigning authority.
- Define semantic precedence for accession, test, status, and timestamps.
- Model preliminary/final/corrected/withdrawn result lifecycle.
- Normalize codes and units without erasing clinical meaning.

## 7. Common Traps
- Splitting only on LF when segments may use CR or CRLF.
- Assuming MSH is first despite batch framing.
- Selecting the first OBX even if it is a comment or another analyte.
- Taking the first PID-3 identifier without checking authority.
- Confusing collection time with receipt or analyzer run time.
- Dropping comparator symbols, units, corrections, or withdrawals.
- Using message control ID as the only business deduplication key.

## 8. Independent Examples
**Identifier authority:** two PID-3 identifiers may both look valid; type and assigning authority determine which matches the contract.

**Time semantics:** a specimen collected at 09:00, received at 10:15, and analyzed at 11:00 should use 09:00 when collection time is required.

**Correction:** a corrected result for the same accession and test supersedes the preliminary result under the applicable status rules.

## 9. Technical Topics to Study
1. HL7 v2 structure and MSH delimiter declarations.
2. PID, SPM, OBR, OBX, MRG, components, and repetitions.
3. LOINC/local code mapping, units, and result statuses.
4. Timestamp precedence, correction/withdrawal lifecycle, and synthetic tests.

## 10. Suggested Learning Plan
1. Identify MSH, PID, OBR, and OBX in a small synthetic message.
2. Write a delimiter-aware parser with explicit index conventions.
3. Add repeated segments and alternate coded identifiers.
4. Implement patient/accession resolution with authority context.
5. Normalize value, unit, status, and timestamps separately.
6. Add result lifecycle transitions and duplicate handling.
7. Test framing, escaping, CR/LF variants, and truncated messages using synthetic data only.

## 11. Validation Checklist
- [ ] Are JSON and HL7 escaping layers decoded correctly?
- [ ] Are framing characters and batch headers handled?
- [ ] Are segment terminators and MSH delimiters respected?
- [ ] Is the correct OBX selected?
- [ ] Are patient ID and accession resolved correctly?
- [ ] Are codes, values, units, flags, and timestamps preserved?
- [ ] Do corrected and withdrawn results supersede prior state appropriately?
- [ ] Are duplicates reconciled by result identity?
- [ ] Is output exactly one row per canonical result?

## 12. Evidence and Assumptions
The README documents the HL7 lab interface, output fields, and protocol, identity, timing, unit, and lifecycle variants. `handler.py` and `gold_submit.py` were reviewed for interface and technical context. HL7 implementations vary; follow the challenge's version and sender-specific rules. Experience ranges are heuristic.
