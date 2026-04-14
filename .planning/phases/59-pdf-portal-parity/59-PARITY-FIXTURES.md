# Phase 59 Parity Fixtures

Shared fixture source for portal, spreadsheet, and payroll PDF parity.

## overnight 24-hour strict day

- outlet mode: `TWENTY_FOUR_HOUR`
- contract type: `FULLTIME`
- logical workday: `2026-03-18`
- expected primary outcome label: `Terlambat`
- expected short tags: `TLT`
- expected severity family: `yellow`
- portal wording: band-first card shows `Pagi`, `Wajib 10j`, then progress/comparison lines with calm helper copy about late arrival
- spreadsheet and PDF meaning: day cell keeps the same primary meaning as portal and uses the `TLT` tag with the late palette

## legacy fallback no-schedule day

- outlet mode: `NORMAL`
- contract type: `PARTTIME`
- logical workday: `2026-03-21`
- expected primary outcome label: `Hadir tanpa jadwal`
- expected short tags: none
- expected severity family: `info`
- portal wording: card explains that payroll is being derived from attendance logs and contract because the schedule row is missing
- spreadsheet and PDF meaning: the same logical day stays informational, uses contract-required hours, and never reintroduces GPS or technical scan metadata
