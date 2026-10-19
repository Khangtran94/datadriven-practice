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

This section estimates the challenge's difficulty and compares the visible patterns in the submission and reference solution. The estimates are heuristic, not validated hiring benchmarks and not a judgment of the author's overall professional seniority.

### 5.1. Overall Comparison

| Evidence Source | Lens | Level | Estimated YoE | Short Rationale |
|---|---|---|---|---|
| Problem statement (README.md) | Challenge difficulty | Senior-level problem-solving in a specialized domain | Approximately 3–5 years of relevant data-integration experience | Correct clinical extraction requires HL7 segment semantics, multiple OBX selection, test-code normalization, MRN identity and merge handling, clinical units/values, result-status precedence, time provenance, and defensive log parsing. |
| Your submission (handler.py) | Demonstrated implementation | Mid-level parsing logic; memory/runtime design assessed separately | Approximately 2–3 years equivalent for the patterns demonstrated | Includes HL7 unescaping, segment splitting, JSON-envelope recovery, test/status maps, timestamp and unit helpers, and merge configuration. Visible settings set APPLY_MERGES to False and EMIT_UNMAPPED_TESTS to True; those choices must be checked against the output contract. |
| Reference solution (gold_submit.py) | Solution sophistication | Senior-level problem-solving patterns | Approximately 4–6+ years of relevant experience | Uses detailed HL7/log recovery, explicit code/unit/status tables, time-zone handling, and structured extraction from multiple message forms. State strategy and memory behavior should be assessed separately from parsing correctness. |

The estimates describe the challenge and observable patterns, not the author's actual tenure or overall ability.

### 5.2. Skill-by-Skill Comparison

| Skill Group | Problem Target | Submission Evidence | Reference Evidence |
|---|---|---|---|
| HL7 segment/field parsing | Mid–Senior | Segment splitting and field helpers | More extensive message extraction and normalization |
| JSON/log escapes and framing | Mid–Senior | Layer unescaping, HL7 escapes, and envelope recovery | More detailed recovery of escaped/truncated log messages |
| Test-code and OBX selection | Mid–Senior | Test-code mapping; verify multiple OBX and alternate LOINC slots | Explicit test-code tables and structured observation selection |
| Patient identity and merge events | Senior-level problem-solving | MRN parsing exists, but merge application is disabled by configuration | More comprehensive patient-identifier and result-key handling |
| Clinical value and unit normalization | Mid–Senior | Decimal and unit helpers | Explicit unit and numeric parsing rules |
| Status and correction precedence | Mid–Senior | Status mapping and rank tables | Explicit status tables and candidate ranking |
| Time provenance and time zones | Mid–Senior | Timestamp and zone utilities | More extensive handling of variable-width timestamps and zone assumptions |
| Memory-efficient streaming | Senior-level problem-solving | Must be assessed from retained state and per-key candidate strategy | State strategy must be checked for bounded memory over the full input |

### 5.3. Evidence Behind the Estimate

- The README describes a large clinical interface feed with multiple HL7 segments, multiple OBX records, alternate test codes, patient-number merges, varied time sources, unit variations, corrected/preliminary/withdrawn results, and log artifacts.
- The submission demonstrates substantial parsing intent: escape normalization, segment splitting, envelope extraction, code maps, status ranks, and timestamp/unit helpers.
- Configuration choices such as disabling merge application and allowing unmapped tests to be emitted should be compared with the output contract. They should not be called defects unless the contract confirms that.
- The reference illustrates a more comprehensive normalization approach. Parsing sophistication and memory efficiency are separate dimensions and should be tested independently.

### 5.4. What Each Level Looks Like Here

| Level | Expected Demonstration |
|---|---|
| Beginner / Entry-level | Splits a simple HL7 message and extracts fields from a stable layout. |
| Junior Data Engineer | Handles common segments, test codes, nulls, and basic type conversion. |
| Mid-level Data Engineer | Selects observations, normalizes identifiers/units/times, and applies result-status rules across sender variations. |
| Senior-level problem-solving | Resolves identity merges and time provenance, handles uncommon valid HL7/log forms, and keeps state bounded under high-volume streaming constraints. |

### 5.5. Assumptions and Limitations

1. README.md defines the target contract; handler.py and gold_submit.py are implementation evidence.
2. The examples are challenge-specific, not a substitute for a hospital interface specification or clinical governance.
3. Whether a configuration flag is wrong depends on the explicit contract and should be verified.
4. Memory suitability depends on the full state lifecycle and input volume, not just parser complexity.
5. YoE ranges are contextual estimates and do not establish the author's career seniority.

**Overall conclusion:** Week 4 is a specialized HL7 integration challenge with Senior-level problem-solving demands. The submission demonstrates ambitious parsing logic; key review areas are contract-aligned merge/test selection, result precedence, time provenance, and bounded streaming state.

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
