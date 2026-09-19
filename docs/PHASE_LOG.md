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

## Phase 3 — Backend core ✅ complete

All nine planned migrations are applied (09 withdrawn — see below). Suite
**862 examples, 0 failures**; rubocop clean; frontend 1179 passing.

### Destructive migrations, done

| # | Migration | Effect |
|---|---|---|
| 02 | `MoveTheOpeningHoursIntoTheSettings` | hours, working days, brand colour backfilled into `settings`, then the four columns dropped |
| 03 | `ForgetTheSitesWeNoLongerHave` | `companies.locations_count` dropped |
| 08 | `GiveAStaffMemberOneRoleNotTwo` | `staff_members.role` enum dropped, `role_id` NOT NULL |
| 09 | — | **withdrawn** |

**Migration 09 was a design error and is withdrawn.** It proposed folding
`platform_settings` into an ENV-backed constant. But `annual_discount_percent`
is edited at runtime by a platform admin through
`PATCH /api/v1/admin/subscription_pricing` — a constant would have deleted a
working feature. A single-row settings table is the right shape for an
admin-editable global. `DATABASE_DESIGN.md` §3 and `MIGRATION_PLAN.md` are
corrected.

### Notes on the destructive work

- **The API did not change.** Hours and branding moved storage only: the
  serializer still emits `business_hours_start`, `business_hours_end`,
  `working_days` and `primary_color` at the top level, the controller still
  accepts them there, and `Company` keeps readers and writers for each. No
  Angular change was needed.
- **Validation moved with the data.** `CompanySettings` coerces anything
  unusable to its default and records it in `#invalid_values`; `Company`
  turns that into validation errors, so a bad hex colour is still a 422
  rather than a value that silently vanishes.
- **A staff member's "kind" became a fact about them.** The dropped enum
  carried two things: permissions (now the Role's job) and whether the login
  coaches. The second moved to `coach_id.present?` — which the five
  coach-narrowing checks already read. Consequence: an owner can now put a
  coach on a custom role and they still reach the coach shell. The API sends
  `role_key` and `is_coach` instead of `role` and `staff_role` meaning the
  same thing twice; the Angular guard and auth service follow.
- **`ModuleCatalog` kept, reduced.** It held a second copy of the permission
  catalogue that `Permissions::Resolve` intersected every role against —
  the direct cause of the `revenue` bug. It is now only the "what your
  subscription includes" display list.

## Phase 4 — Authorization & tenant isolation 🔶 in progress

### Done

- **`spec/requests/security/`** — 59 examples across three files:
  `tenant_isolation_spec.rb` (33), `role_boundaries_spec.rb` (22),
  `impersonation_spec.rb` (4). Every example is a denial.
- **Member tokens are refused on staff endpoints explicitly**
  (`BaseController#reject_member_token!`). Previously incidental, via
  `require_company!` rendering 422 — and a controller whose capability check
  ran first would have raised on `current_user.owner?` with a nil user.
- **Impersonation is auditable throughout the session**, not just at its
  start, via `Current.impersonator` read by `AuditLogs::Record`.
- **`email_verifications#create` throttled** — the one unauthenticated
  account-mail endpoint with no ceiling.

### Corrections to the Phase 1 analysis, found by doing the work

1. A tenant-scoping RuboCop cop (`Fitora/UnscopedTenantQuery`) already
   existed and fails the build on bare `Model.find` for ~19 models. Phase 1
   called for building one. `Space`/`ActivitySpace` were added to it.
2. Rack::Attack already existed and was thorough. Phase 1 said there was no
   evidence of it.
3. `revenue` was missing from `ModuleCatalog::ALL_PERMISSIONS`, silently
   stripped from every advertised permission list including the owner's.
   Latent only because no frontend guard read it yet.

### Also done

- **`spec/requests/security/foreign_ids_spec.rb`** (9 examples) — the cases
  the cop cannot see, where a foreign id arrives inside a nested write: a
  coach, a role, an activity, a room or an attachment belonging to another
  gym. All nine passed first time; the defences (scoped lookups and
  same-company model validations) were already in place.
- **`spec/architecture/strong_params_spec.rb`** (8 examples) — reads the
  controller sources, so a new controller is covered the day it is written.
  Asserts no controller permits `company_id`, `password_digest`,
  `token_version`, the verification/reset token digests, or any real counter
  cache column, and that no controller resolves a company from params.
  Counter caches are read from the associations that declare them, not
  guessed from names ending in `_count` — `contract_types.session_count` is
  a field an owner sets, not a cache.
- **Support ticket attachments verified** — `@ticket.attachments.find` under
  a `current_company`-scoped ticket. The Phase 1 doc flagged this as
  unverified; it was already correct.

Phase 4 total: **68 security examples**. Suite **879 examples, 0 failures**.

### Remaining in Phase 4

Nothing blocking. Two things deliberately deferred to the phase that needs
them:

- Per-endpoint capability coverage for the `/coach/*` and `/desk` surfaces,
  which do not exist yet (Phase 6).
- The `settings` capability is defined and enforced on nothing yet — the
  company settings endpoints still gate on `require_owner!`. It gets wired
  when the settings UI is built (Phase 8).

## Phase 5 — Frontend architecture 🔶 in progress

### Done

- **The desk shell exists** (`layout/desk-shell/`, `features/desk/`). The
  receptionist stops borrowing the owner shell. Search-first: the member
  search is the top of every desk screen, focused on load (skipped on touch),
  debounced at 250ms, minimum two characters.
- **`features/desk/dashboard`** — the session under way, two counts (expected
  / turned up), what is still to come, memberships about to lapse, new
  members. No totals, no revenue, no charts.
- **`features/desk/checkin`** — today's sessions only, `?session=` preselects
  one, and a stale id falls back to the picker rather than an empty roster.
- **`deskAreaGuard`** — requires `checkin` AND `bookings` (checkin alone is a
  coach), turns away coaches, owners and admins, and honours the trial lock.
- **`AuthService#deskShellApplies`** sends desk staff to `/desk/dashboard`
  after login.
- **`_adminlte.scss` renamed to `_shell.scss`.** Nothing in it was AdminLTE.
- 26 new frontend examples; suite **1210 passing**, lint clean, builds clean,
  i18n complete in fr/en/ar (775 keys).

### Deliberately deferred

**The `_fitora.scss` decomposition is NOT done, and the "under 250 lines"
target in `UI_ARCHITECTURE.md` §1 is wrong as written.** That file is mostly a
Bootstrap *override* layer — it restyles `.btn`, `.form-control`, `.table`,
`.alert`, `.badge` with Fitora tokens, and those classes are used across 49
templates. It cannot be scoped to components or shrunk while the templates
still use Bootstrap classes. Splitting it cosmetically now and rewriting it
again in Phase 7 would be wasted work, so it moves to Phase 7, where the
templates are rewritten anyway.

### Remaining in Phase 5

- The new primitives (`data-table`, `stat-tile`, `sheet`,
  `date-range-picker`, `segmented-control`, `entity-card`).
- `features/` restructure for the coach and member additions (Phase 6 needs
  them).

## Phases 6–10 — not started

See `MIGRATION_PLAN.md` §4.
