# Phase 54: Workforce Contract & Outlet Mode Foundation - Context

**Gathered:** 2026-03-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Add explicit employee contract metadata (`FULLTIME` / `PARTTIME`) and outlet operating-mode metadata (`NORMAL` / `TWENTY_FOUR_HOUR`) across the live admin data model without breaking existing employee, outlet, or import flows. Strict lateness, red/yellow recap evaluation, overnight payroll logic, and export redesign stay out of scope for this phase.

</domain>

<decisions>
## Implementation Decisions

### Employee contract defaults
- Existing active employees should be backfilled to `FULLTIME` as the safe rollout default.
- New or edited employees must always have a contract value before save; `null` contract states are not acceptable.
- In the add/edit employee form, the initial UI default should be `PARTTIME`, but admin or kepala gerai can switch it to `FULLTIME` before saving.
- The canonical stored system values are `FULLTIME` and `PARTTIME`.
- Archived or inactive employees keep their last known contract value for history and audit purposes.

### Outlet operating mode
- Existing outlets should be backfilled to `NORMAL` as the safe rollout default.
- Every active outlet must always have an operating mode value; this field should not be nullable in normal app usage.
- Only full admin should be allowed to change outlet operating mode.
- Outlet mode must be visible both in the outlet edit sheet and as a compact badge in the outlet list so rollout review is fast.

### Admin surfaces
- Employee contract should be visible as a compact badge in the active employee list.
- Employee list should gain a contract filter from Phase 54 onward for rollout review and later payroll preparation.
- Kepala gerai can edit employee contract values for employees within their own locked outlet scope.
- In the employee form, contract selection should use direct segmented chips rather than a hidden dropdown.
- Contract badges should use strong but neutral branding, not red/yellow warning language that will later belong to attendance evaluation.
- The employee list should default to showing all contracts when first opened.
- Archived employee surfaces should keep showing the stored final contract value for audit consistency.
- The employee sheet does **not** need to show the selected outlet's `NORMAL` / `TWENTY_FOUR_HOUR` mode as an extra hint in Phase 54.

### CSV import contract support
- Batch employee CSV import is within Phase 54 scope because it is an existing employee-creation path that now needs contract metadata.
- CSV import must require a contract column for every row.
- CSV parser should store canonical `FULLTIME` / `PARTTIME` values but may accept common aliases such as `PARTIME`, `part-time`, or case variations and normalize them.
- Legacy templates that do not include the contract column should be rejected with a clear operator-facing error instead of silently defaulting values.
- The downloadable CSV template must be updated to include the contract column and valid sample values.

### Claude's Discretion
- Exact database column names, enum implementation details, and migration choreography, as long as the live rollout stays additive and the stored values remain `FULLTIME` / `PARTTIME` plus `NORMAL` / `TWENTY_FOUR_HOUR`.
- Exact badge colors, chip styling, and layout spacing, as long as contract visuals stay distinct from future red/yellow attendance exception colors.
- Exact wording for operator-facing CSV validation errors and normalization help text.

</decisions>

<specifics>
## Specific Ideas

- The user wants kepala gerai to remain able to assign crew contracts directly from their existing employee-management flow.
- The user explicitly called out batch CSV onboarding as a critical place where the new contract attribute must not be forgotten.
- The user prefers rollout defaults that keep live data usable immediately, then allow manual correction through visible admin audit surfaces.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/models/employee.dart`: current employee model already carries `position`, `employee_code`, `home_outlet_id`, `is_active`, and archive state; it is the main place to add typed contract metadata.
- `lib/models/outlet.dart`: current outlet model is simple and typed, making it the natural place to add operating-mode metadata.
- `lib/screens/admin/admin_employees_screen.dart`: existing employee bottom sheet already saves name, position, employee code, outlet, and active status; this is the primary integration point for contract controls.
- `lib/screens/admin/admin_outlets_screen.dart`: current outlet sheet already handles outlet CRUD and is the natural place to add operating-mode editing.
- `lib/services/csv_import_service.dart`: parsing, validation, payload building, and template generation are already centralized as mostly pure functions, so contract-column support can stay isolated and testable.

### Established Patterns
- Admin CRUD flows use direct Supabase `insert` / `update` payloads from bottom sheets rather than a separate repository layer.
- Kepala gerai restrictions are enforced by locking outlet scope in the admin employee screen, so contract editing should follow that same pattern instead of inventing a new permission surface.
- Models use immutable typed classes with `fromJson`, `toJson`, and `copyWith`.
- CSV import is intentionally structured as pure parse/validate/build steps before the one side-effecting insert call.

### Integration Points
- `lib/models/employee.dart` and any joined employee query consumers must understand the new contract field.
- `lib/models/outlet.dart` and outlet list/sheet queries must understand the new outlet operating mode.
- `lib/screens/admin/admin_employees_screen.dart` needs the new contract input, list badge, and filter wiring.
- `lib/screens/admin/admin_outlets_screen.dart` needs the new outlet-mode input plus list visibility.
- `lib/services/csv_import_service.dart`, its template output, and any import result presentation must be extended to require and normalize contract values.

</code_context>

<deferred>
## Deferred Ideas

- Strict lateness, short-work, excess-break, overtime, and exempt-manager evaluation belong to later phases, not Phase 54.
- Overnight-safe recap calculation and payroll matrix exports belong to Phases 57-59.
- Any automatic payroll amount calculation, overtime approval workflow, or payslip generation remains outside this phase.

</deferred>

---

*Phase: 54-workforce-contract-outlet-mode-foundation*
*Context gathered: 2026-03-26*
