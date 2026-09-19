# Fitora — Transformation Progress Log

Running record of what is actually done, so any session can resume without
re-deriving state. Update it at the end of every work block.

Test baseline before any of this work: **705 examples, 0 failures.**

---

## Phase 1 — Analyse ✅ (2026-09-19)

`CURRENT_ARCHITECTURE.md`. Key finding: the codebase was substantially closer
to the target than the brief assumed.

## Phase 2 — Design ✅ (2026-09-19)

`TARGET_ARCHITECTURE.md`, `DOMAIN_MODEL.md`, `PERMISSIONS.md`,
`DATABASE_DESIGN.md`, `API_DESIGN.md`, `UI_ARCHITECTURE.md`,
`MIGRATION_PLAN.md`.

Four decisions taken by the product owner, recorded in
`TARGET_ARCHITECTURE.md` §0: full domain rewrite, spaces optional per
company, keep the Contract/ContractType/ContractPeriod names, full UI
redesign.

## Phase 3 — Backend core 🔶 in progress

### Done — suite green at **789 examples, 0 failures**, rubocop clean

**Migrations applied** (all additive and reversible):

| # | Migration | Effect |
|---|---|---|
| 01 | `LetACompanyConfigureItself` | `companies.settings` jsonb + GIN index |
| 04 | `GiveACompanyItsRoomsBack` | `spaces`, `activity_spaces` |
| 05 | `PutASessionInARoom` | `sessions.space_id` + `no_overlapping_space_sessions` GiST exclusion |
| 06 | `LetOneContractCoverEveryActivity` | `contracts.activity_id` nullable |
| 07 | `HoldAPlaceInTheQueue` | `bookings.waitlist_position` + check constraint |

**The configuration engine**

- `CompanySettings` — typed, immutable, closed-schema value object over the
  JSONB. Unknown keys dropped on write and reported via `#unknown_keys`;
  booleans cast from what forms and JSON actually send; integers clamped to
  range rather than rejected. `Company#settings`, `#settings=`, `#feature?`.
- Sections live today: `features` (7 flags), `booking` (3 rules). `hours` and
  `branding` join in migration 02, which is destructive and deferred.

**Spaces** — `Space`, `ActivitySpace` models; `SpaceSerializer`;
`Api::V1::SpacesController` (full CRUD, feature-gated 404, capability-gated
writes, activity restriction sync scoped to the company's own activities);
`resources :spaces` routed. Deleting a room deactivates it while sessions
remain and deletes it once nothing upcoming needs it; past sessions keep
their history with the room unset.

**Multi-activity contracts** — `Contract#covers_activity?`, `#all_access?`,
`#covered_activities`. `ContractType#price_for(nil)` answers the all-access
price (dearest covered activity). `#grants_access_to?` now nil-safe.

**Booking rules, driven by settings** — `online_booking`,
`booking_opens_days` and `cancellation_hours` enforced in
`Bookings::Create` / `Bookings::Cancel`, applied to members (`by: :member`)
and deliberately not to staff. `Bookings::PromoteFromWaitlist` added;
waitlist join, ordering, promotion and resequencing all behind the
`waitlist` feature flag.

**Permissions** — added `spaces` and `settings` capabilities.

**Fixed along the way**

- `revenue` was missing from `ModuleCatalog::ALL_PERMISSIONS`, so
  `Permissions::Resolve` silently stripped it from every advertised
  permission list including the owner's. Latent (no frontend guard read it
  yet); would have broken Phase 6.
- A flaky spec: `expect(response.body).not_to include("240")` in the member
  profile spec matched random UUIDs. Now asserts on parsed values.
- `Fitora/UnscopedTenantQuery` cop taught about `Space` and `ActivitySpace`.

**Reverted deliberately** — a `Contract` validation requiring its activity to
be covered by its plan. Correct at the point of sale, but it would make every
contract un-saveable (including un-cancellable) the moment an owner removed
an activity from a plan. Coverage is enforced at booking time instead.

### Remaining in Phase 3

- Migration 02 — backfill `business_hours_*`, `working_days`, `primary_color`
  into `settings`, then drop those columns. **Destructive.** Touches the
  company serializer, the company controller and the Angular app.
- Migration 03 — drop `companies.locations_count`. **Destructive.**
- Migration 08 — backfill `staff_members.role_id`, set NOT NULL, drop the
  `role` enum and the sync hook. **Destructive.**
- Migration 09 — drop `platform_settings`, move the one integer to config.
  **Destructive.**
- Delete `ModuleCatalog` once nothing reads it.
- A `spaces` / booking-rules section in the settings API and bootstrap
  payload for the frontend to read.

Per `MIGRATION_PLAN.md` §5, migrations 02, 03, 08 and 09 are the point of no
return and belong in one window after a rehearsal against a restored dump.

## Phases 4–10 — not started

See `MIGRATION_PLAN.md` §4.
