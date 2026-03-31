# v8.1 Research - Pitfalls

**Milestone:** v8.1 Reporting Recovery & Schedule Gap Notifications  
**Research date:** 2026-03-31

## Highest-risk mistakes

### 1. Overwriting strict rows with fallback rows

If fallback logic starts replacing days that already have valid strict recap
output, v8.1 would silently remove break-first, lateness, or excess-break
signals that the user explicitly wants to keep.

**Prevention:** keep strict-row precedence absolute and test mixed datasets.

### 2. Treating missing schedules as payroll violations

The user wants empty schedules to become notifications, not recap corruption. If
schedule-gap detection re-enters red/yellow cell semantics, the same regression
returns under a different name.

**Prevention:** separate schedule-gap audit state from recap primary status.

### 3. Weakening contract-aware break rules in compatibility mode

The user explicitly called out break-first and excess-break behavior. If
compatibility mode accidentally turns those into generic "hadir tanpa jadwal"
days, the strict rule set loses value exactly where the user still trusts it.

**Prevention:** preserve contract thresholds whenever the day has enough data to
evaluate them honestly.

### 4. Breaking overnight grouping while fixing legacy continuity

Legacy no-schedule support must still respect `TWENTY_FOUR_HOUR` logical-day
grouping. Otherwise the corrective milestone fixes one class of report but
reintroduces cross-midnight regressions.

**Prevention:** keep overnight fixtures in recap, spreadsheet, and PDF tests.

### 5. Diverging admin recap from spreadsheet/PDF again

The main value left in v8.0 is parity. Fixing admin recap without running the
same corrected dataset through spreadsheet and PDF would recreate semantic
drift.

**Prevention:** require one shared merged dataset for all salary-facing outputs.

### 6. Leaking technical or migration-oriented fields into exports

When teams debug fallback behavior, there is a temptation to expose internal
fields in exports. The current export services intentionally block that.

**Prevention:** keep export field policy unchanged and test forbidden fields.

### 7. Shipping a notice system that depends on perfect schedule data

If the notification feature only works after a complete backfill or only from
one narrow admin surface, it will not solve the real outlet workflow problem.

**Prevention:** design notices as best-effort operational follow-up from
current data, not as a migration-complete feature.

## Phase mapping

| Pitfall | Best phase to address |
|---------|-----------------------|
| Strict/fallback overwrite | report-semantics phase |
| Missing schedule as penalty | report-semantics phase |
| Lost break-first/excess-break strictness | report-semantics phase |
| Overnight regression | report-semantics plus verification phase |
| Export drift | export parity phase |
| Technical-field leakage | export parity phase |
| Weak notification UX | schedule-gap notice phase |

## Conclusion

The biggest architectural risk is mixing operational schedule completeness with
payroll evidence semantics. v8.1 should keep those separate.
