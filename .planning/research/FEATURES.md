# Feature Research

**Domain:** Employee-facing attendance recap in a restaurant attendance portal
**Researched:** 2026-03-23
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Day-by-day attendance history | Employees need to confirm what the system recorded for their recent workdays | MEDIUM | Must show status and the recorded timestamps that explain that status. |
| Month-to-date summary counts | A recap feels incomplete without a quick totals view | MEDIUM | Keep counts concrete and simple, not payroll-style calculations. |
| Clear exception visibility | Employees mainly check recap when something looks wrong | MEDIUM | Missing clock-out, sakit, izin, and libur need distinct presentation. |
| Mobile-first portal layout | The current portal is phone-first and employees already access it that way | LOW | Reuse the existing portal shell and card/list patterns. |

### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Schedule context beside recap days | Helps employees understand whether a missing punch is tied to a scheduled shift | MEDIUM | Leverages the existing schedule model instead of making recap a blind log dump. |
| Exception-first attention markers | Directs employees to days that need follow-up without scanning the whole list | MEDIUM | Useful foundation before a later correction or request workflow exists. |
| Consistent logical-day handling | Builds trust because the portal matches kiosk/admin interpretations of overnight work | MEDIUM | Critical for restaurant shifts that cross midnight. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Time-off request submission in the same milestone | Feels related to attendance recap | Adds write paths, approval rules, and admin workflow complexity to a read-only milestone | Ship recap first, then build requests as the next milestone. |
| Payroll-grade calculations or downloadable statements | Employees often equate recap with payroll | Pulls the milestone into salary policy, deductions, and finance accuracy concerns | Keep v6.3 focused on attendance visibility, not payroll output. |
| Real-time push updates | Sounds modern | Unnecessary for a recap page and adds state complexity | Use standard page refresh on the server-rendered portal. |

## Feature Dependencies

```text
Attendance recap surface
    └──requires──> employee-scoped recap read model
                          └──requires──> existing portal auth + employee resolution

Month summary cards ──enhances──> day-by-day attendance history

Request submission workflow ──conflicts──> tight read-only v6.3 scope
```

### Dependency Notes

- **Attendance recap surface requires employee-scoped recap read model:** the UI should not compose attendance meaning from multiple ad hoc queries.
- **Month summary cards enhance day-by-day history:** summary counts make the history scannable but depend on the same trusted dataset.
- **Request workflow conflicts with tight recap scope:** it introduces writes, approvals, and notifications that are better handled as a follow-up milestone.

## MVP Definition

### Launch With (v6.3)

- [ ] Attendance recap entry point in the existing portal
- [ ] Month-to-date summary counts with concrete attendance states
- [ ] Recent day-by-day history with timestamps and shift context
- [ ] Exception highlighting for incomplete or non-standard attendance days

### Add After Validation (v6.3.x)

- [ ] Short date-range switches (for example current month vs previous month) once the base recap proves useful
- [ ] Better employee-facing explanation text for exception days based on support feedback

### Future Consideration (v6.4+)

- [ ] Employee attendance correction requests
- [ ] Admin approval workflow for employee requests
- [ ] Shift reminders or attendance notifications

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Day-by-day attendance history | HIGH | MEDIUM | P1 |
| Month-to-date summary counts | HIGH | MEDIUM | P1 |
| Exception visibility | HIGH | MEDIUM | P1 |
| Date-range filters | MEDIUM | MEDIUM | P2 |
| Correction request workflow | HIGH | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | Attendance/time portals commonly do | Enterprise time-tracking suites commonly do | Our Approach |
|---------|-------------------------------------|--------------------------------------------|--------------|
| Personal attendance history | Show recent daily records with status and punch times | Show day/week/month time sheets | Deliver a recent-history view first, optimized for mobile employees. |
| Summary counts | Show current-period totals or worked-day summaries | Show period totals plus approval context | Keep month-to-date count cards without dragging v6.3 into approvals. |
| Exceptions | Highlight missing punches or irregular days | Highlight alerts before approval | Surface attention states clearly so employees know which day needs follow-up. |

## Sources

- Local repo: current deferred backlog in `.planning/PROJECT.md`
- Local repo: shipped portal UX in `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\pages\portal\index.astro`
- Local repo: mobile schedule component patterns in `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\components\portal\PortalScheduleSection.astro`
- https://help.sap.com/doc/8cd7b02f4e9c4a569bab136a7caa116e/2405/en-US/SAP%20SuccessFactors%20Time%20Tracking%201H%202024.pdf — reference point for employee-facing time sheet, alert, and approval feature norms

---
*Feature research for: employee portal attendance recap*
*Researched: 2026-03-23*
