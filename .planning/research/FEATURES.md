# Feature Research

**Domain:** Smart Attendance Management + Admin Dashboard (restaurant chain, NFC kiosk)
**Researched:** 2026-03-18
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features the admin/kepala gerai will expect given the milestone scope. Missing these = feature feels half-baked.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| NFC double-scan fix | Crash during registration is a production blocker; users expect registration to work reliably | LOW | Guard NFC listener state during registration flow, disable scan while write-in-progress. Existing `nfc_manager` has session control. |
| Missing clock-out notification | Standard in every attendance system (Workforce.com, Buddy Punch, etc.); admins expect to know when someone forgot to scan out | MEDIUM | Timer-based: if employee has `masuk` but no `pulang` after X hours (configurable, default 10h), push notification to admin. Uses existing notification infrastructure (MethodChannel primary). |
| Attendance rate card widget | Every HR dashboard shows present/absent/late rates; kepala gerai expects at-a-glance metrics | MEDIUM | Percentage card showing daily/weekly/monthly attendance rate per outlet. Query `attendance_logs` grouped by date, compare against active employee count. Builds on existing `_todayMasuk` counters in `AdminDashboardScreen`. |
| Overtime tracking | Restaurant industry mandates overtime awareness for labor cost control; admins expect to see who worked extra hours | MEDIUM | Calculate hours between `masuk` and `pulang`, compare against standard shift duration (from `shift_templates`). Flag entries exceeding threshold. No complex pattern detection needed -- straight arithmetic on existing data. |
| Kepala Gerai onboarding via app | Currently SQL-only (Decision #7); adding even one more outlet makes SQL unscalable. Admin expects in-app user creation. | MEDIUM | Supabase Auth `admin.createUser()` via Edge Function (client SDK cannot create users for others). Auto-generate email pattern (`kepala.[outlet]@enakko.internal`) + random password. Copy-to-clipboard for WhatsApp sharing. |

### Differentiators (Competitive Advantage)

Features that set Absenkok apart from paper attendance and basic clock-in apps. Not expected by users, but create "wow" moments.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Smart attendance pattern detection (BETA) | Most restaurant attendance systems are reactive (record, report). Proactive pattern detection ("Budi biasanya masuk 07:00, hari ini belum scan jam 07:05") is a differentiator | HIGH | Analyze last 30 days of `masuk` timestamps per employee, compute median arrival time per day-of-week. "Late" = deviation > configurable threshold (default 5 min). Runs client-side on dashboard load. 14 employees x 30 days = small dataset, median is robust enough. Mark BETA -- accuracy improves with data volume. |
| Gamification streak | Duolingo/GitHub-style streaks for attendance. Restaurant employees are young, respond well to gamification. Industry reports show 40% reduction in late arrivals with gamification. | MEDIUM | Track consecutive on-time `masuk` days. Store streak count + last streak date on `employees` table (2 new columns). Display on kiosk scan result screen + admin dashboard. Builds on existing badge system (`badges` table, `BadgeAvatar` widget). Award auto-badges at milestones (7-day, 30-day, 90-day). |
| Mini chart dashboard (1-screen recap) | Kepala gerai sees everything in one screen without navigating. Most attendance apps require multiple clicks to get insights. | HIGH | Single scrollable screen with: attendance rate donut chart, weekly trend bar chart, top streaks leaderboard, overtime alerts, missing clock-outs. Requires charting library (fl_chart -- lightweight, sufficient for this scope). |
| Cross-outlet attendance comparison | Multi-outlet visibility in one view. Unique to chain operations -- single-outlet apps cannot do this. | MEDIUM | Bar chart or table comparing attendance rates across 4 outlets. Admin-only (not kepala gerai, who is outlet-scoped). Query `attendance_logs` joined with `outlets`, group by `scan_outlet_id`. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| ML-based prediction ("will employee be absent tomorrow?") | Sounds futuristic and smart | 14 employees, 89 attendance logs -- far too little data for meaningful ML. False predictions erode trust. Training/inference overhead on a kiosk tablet is inappropriate. | Use simple statistical median for pattern detection. Honest "BETA" label. Upgrade to ML only at 200+ employees with 6+ months of data. |
| Real-time push to employee phones | Employees want their own late notifications | Employees use NFC cards on a shared kiosk -- they do not have the app installed on personal phones. Building a separate employee mobile app is out of scope. | Notify admin/kepala gerai only. Admin communicates to employee verbally or via existing WhatsApp group. |
| Complex gamification (levels, XP, shop, rewards) | Full gamification platforms show engagement | Over-engineering for 14 restaurant employees. Maintenance burden. Distraction from core attendance purpose. | Simple streak counter + auto-badge awards. Keep it lightweight. Can expand later if employees respond well. |
| Automated schedule adjustment based on patterns | "If Budi always comes at 09:00, auto-assign Siang shift" | Schedules are owner/kepala gerai decisions, not algorithmic. Auto-changes cause confusion. Shift assignment involves business logic (coverage needs) that algorithms cannot understand. | Show pattern insights to admin as recommendation, let human decide. |
| GPS/geofencing validation | Many attendance apps add location verification | This is a fixed NFC kiosk -- the physical card tap IS the location proof. GPS adds battery drain, permission complexity, and zero value for a stationary tablet. | NFC tap on outlet-registered device is sufficient location proof. Already have `scan_outlet_id` linking to outlet. |

## Feature Dependencies

```
[Kepala Gerai Onboarding]
    (standalone -- no dependencies)

[NFC Double-Scan Fix]
    (standalone -- no dependencies, critical bug fix)

[Attendance Rate Card]
    (standalone -- builds on existing attendance_logs queries)

[Missing Clock-Out Notification]
    └──requires──> [Attendance Rate Card logic] (shared query patterns)
    └──requires──> [Existing notification infrastructure] (already built)

[Overtime Tracking]
    └──requires──> [shift_templates data] (already exists)
    └──enhances──> [Attendance Rate Card] (can show overtime hours in card)

[Smart Pattern Detection]
    └──requires──> [Historical attendance_logs] (already have 89+ rows)
    └──enhances──> [Missing Clock-Out Notification] (pattern-aware thresholds)
    └──enhances──> [Overtime Tracking] (detect habitual overtime)

[Gamification Streak]
    └──requires──> [Smart Pattern Detection] (needs "on-time" definition)
    └──enhances──> [Existing badge system] (auto-award streak badges)

[Mini Chart Dashboard]
    └──requires──> [fl_chart library] (new dependency)
    └──requires──> [Attendance Rate Card] (rate data feeds charts)
    └──requires──> [Overtime Tracking] (overtime data feeds charts)
    └──requires──> [Gamification Streak] (streak leaderboard widget)

[Cross-Outlet Comparison]
    └──requires──> [Attendance Rate Card logic] (per-outlet calculation)
    └──enhances──> [Mini Chart Dashboard] (can be a widget in dashboard)
```

### Dependency Notes

- **NFC Double-Scan Fix** and **Kepala Gerai Onboarding** are independent and should ship first (bug fix + admin workflow).
- **Attendance Rate Card** is the foundational data query that overtime, pattern detection, and dashboard all build on. Must be solid before adding visual layers.
- **Smart Pattern Detection requires historical data** -- with only 89+ logs currently, the algorithm will be approximate. Mark as BETA and improve as data accumulates.
- **Gamification Streak depends on "on-time" definition** from pattern detection. Without knowing an employee's usual time, you cannot determine if they were "on time." Alternative: define on-time as "before shift start from schedule_entries" which avoids the pattern dependency but is less smart.
- **Mini Chart Dashboard is the aggregator** -- it consumes data from rate card, overtime, streaks, and cross-outlet. Build it last.
- **Cross-Outlet Comparison is admin-only** -- kepala gerai should NOT see other outlets' data (they are outlet-scoped per existing `managedOutletId` logic).

## MVP Definition

### Phase 1: Bug Fix + Admin Workflow (ship first)

- [x] NFC double-scan fix -- production crash, blocks employee registration
- [x] Kepala Gerai onboarding via app -- removes SQL dependency for new outlet setup

### Phase 2: Core Analytics (data foundation)

- [ ] Attendance rate card widget -- daily/weekly/monthly rates per outlet
- [ ] Overtime tracking -- hours calculation against shift templates
- [ ] Missing clock-out notification -- timer-based admin alert

### Phase 3: Smart Features (BETA, builds on Phase 2 data)

- [ ] Smart attendance pattern detection -- median arrival time analysis
- [ ] Gamification streak -- consecutive on-time days + auto-badges

### Phase 4: Dashboard + Visualization (aggregates everything)

- [ ] Mini chart dashboard -- single-screen recap with fl_chart
- [ ] Cross-outlet attendance comparison -- multi-outlet bar chart

### Defer to Future

- [ ] Employee-facing mobile app -- out of scope (kiosk-only)
- [ ] ML-based absence prediction -- insufficient data volume
- [ ] Complex gamification (levels, shop, rewards) -- over-engineering for 14 employees

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| NFC double-scan fix | HIGH | LOW | P1 |
| Kepala Gerai onboarding | HIGH | MEDIUM | P1 |
| Attendance rate card | HIGH | MEDIUM | P1 |
| Missing clock-out notification | HIGH | MEDIUM | P1 |
| Overtime tracking | MEDIUM | MEDIUM | P2 |
| Smart pattern detection (BETA) | MEDIUM | HIGH | P2 |
| Gamification streak | MEDIUM | MEDIUM | P2 |
| Mini chart dashboard | HIGH | HIGH | P2 |
| Cross-outlet comparison | LOW | MEDIUM | P3 |

**Priority key:**
- P1: Core value -- fix bugs, enable admin workflows, provide basic analytics
- P2: Differentiators -- smart features that make Absenkok stand out
- P3: Nice to have -- valuable for multi-outlet admin but not blocking

## Competitor Feature Analysis

| Feature | Basic Clock Apps (Jibble, Clockify) | Enterprise HR (Paycom, Workforce.com) | Absenkok Approach |
|---------|-------------------------------------|---------------------------------------|-------------------|
| Clock in/out | QR/GPS/biometric | All methods + geofencing | NFC card tap (fastest, no phone needed) |
| Late detection | Manual threshold | AI-powered with schedule integration | Statistical median from historical data (BETA) |
| Missing punch alerts | Some offer it | Standard feature | Timer-based notification to admin |
| Overtime tracking | Basic hour counting | Full labor law compliance engine | Hours vs shift template comparison |
| Dashboard charts | Basic or premium-only | Full analytics suite | fl_chart widgets in single-screen recap |
| Gamification | Not offered | Rare (OnShift for senior care) | Streak counter + auto-badges (lightweight) |
| Multi-outlet comparison | Not applicable (single-site) | Enterprise feature | Built-in for 4-outlet chain |
| Offline support | Rarely | Sometimes | SQLite queue, always works (existing) |

## Implementation Notes

### Smart Pattern Detection Algorithm (BETA)

```
For each employee:
  1. Query last 30 days of `masuk` timestamps
  2. Group by day_of_week (Mon-Sun)
  3. Compute median arrival time per day_of_week
  4. "Usual time" = median (more robust than mean against outliers)
  5. "Late" = actual_arrival > usual_time + threshold (default 5 min)
  6. Edge case: employee with < 5 data points for a day -> skip that day
```

Run client-side on dashboard load (14 employees, 30 days = small dataset). No need for Edge Function or cron at this scale.

### Gamification Streak Calculation

```
For each employee:
  1. Get all `masuk` logs ordered by date DESC
  2. Walk backwards from today
  3. If day has `masuk` AND arrival <= usual_time + threshold -> streak++
  4. If day has `masuk` BUT late -> break streak
  5. If day has no `masuk` AND is not scheduled (check schedule_entries) -> skip
  6. If day has no `masuk` AND is scheduled -> break streak
  7. Store: current_streak, longest_streak, last_streak_date
```

New columns on `employees` table: `current_streak INT DEFAULT 0`, `longest_streak INT DEFAULT 0`, `last_streak_date DATE`. Update on each `masuk` scan.

### Missing Clock-Out Detection

```
Trigger: Periodic check (every 30 min via flutter_foreground_task timer)
Logic:
  1. Query today's `masuk` logs without matching `pulang`
  2. For each, check if (now - masuk_time) > threshold (default 10 hours)
  3. If yes -> send notification to admin via existing MethodChannel
  4. Deduplicate: track notified employee_ids in SharedPreferences for today
```

### Dashboard Widget Layout (Mini Chart)

```
SingleChildScrollView
  Row: [AttendanceRateDonut, OvertimeCard]
  WeeklyTrendBarChart (7 bars, Mon-Sun attendance %)
  StreakLeaderboard (top 5 employees by current_streak)
  MissingClockOutAlerts (list of employees not yet scanned out)
  (Admin only) CrossOutletComparison (4-bar chart)
```

## Sources

- [Attendance Tracking for Field Employees 2026](https://www.zfour.in/post/field-employee-attendance-tracking-2026)
- [AI-Based Smart Attendance System](https://www.pockethrms.com/blog/ai-based-smart-attendance-system/)
- [HRMS Time & Attendance: Gamification Tips](https://www.hrmsworld.com/hrms-time-attendance-4-tips-for-gamification-success-620.html)
- [Gamifying Employee Attendance (OnShift)](https://www.onshift.com/resources/blog/gamifying-employee-attendance-to-reduce-labor-costs)
- [Designing Streaks for Long-Term Growth](https://www.mindtheproduct.com/designing-streaks-for-long-term-user-growth/)
- [HR Attendance Dashboard Examples (Bold BI)](https://www.boldbi.com/dashboard-examples/hr/attendance-dashboard/)
- [Attendance Insights Dashboard Widgets](https://success.orah.com/en/articles/9924908-attendance-insights-dashboard-all-widgets)
- [Real-Time Notifications in Time Clock Software](https://www.opentimeclock.com/feature-real-time-notifications.html)
- [Shift Attendance Notifications (Insightful)](https://help.insightful.io/en/articles/6579497-shift-attendance-notifications)
- [Restaurant Time and Attendance Software Guide](https://www.restaurant365.com/blog/time-and-attendance-software/)
- [Flutter Charts (Syncfusion)](https://www.syncfusion.com/flutter-widgets/flutter-charts)
- [fl_chart comparison (Flutter Gems)](https://fluttergems.dev/plots-visualization/)

---
*Feature research for: Smart Attendance + Admin Dashboard (Absenkok v4.0)*
*Researched: 2026-03-18*
