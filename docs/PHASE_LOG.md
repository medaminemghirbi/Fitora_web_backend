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

### The planned primitives, reconsidered

`UI_ARCHITECTURE.md` §5 listed six to add. Four are not being built, and the
doc is corrected:

| Primitive | Verdict |
|---|---|
| `stat-tile` | **Dropped** — `kpi-card` already is this. |
| `sheet` | **Dropped** — `drawer` already is this, with a focus trap. A bottom placement would be an input on it, not a new component. |
| `segmented-control` | **Dropped** — no screen asks for one. `status-filter` covers the rail case. |
| `date-range-picker` | **Deferred** — speculative until a screen needs it. |
| `data-table` | **Deferred to Phase 7.** Today's list pages carry rich per-cell content (avatars, highlight pipes, badges); a column-config table would fight that. It belongs with the rewrite that will consume it. |
| `entity-card` | **Deferred to Phase 7** for the same reason — the desk and coach lists each needed a slightly different shape, and generalising from two is guessing. |

Building primitives with no consumer is the overengineering the brief's §31
warns about. They get built when a screen asks.

## Phase 6 — Role dashboards 🔶 in progress

### Done

- **`GET /api/v1/coach/members`** (`Api::V1::Coach::MembersController`) —
  everyone with a live booking on this coach's own sessions, with
  `last_seen_at` / `next_session_at`. 12 request specs.
- **`features/coach/members`** — the coach's own roster, searchable, with an
  "away" flag on anyone three weeks absent and nothing booked.
- **The coach shell's top bar follows the route** instead of always reading
  "Today".

**The `/coach/*` namespace in `API_DESIGN.md` §3 is mostly withdrawn.** It
proposed `/coach/sessions`, `/coach/sessions/:id` and
`/coach/sessions/:id/attendance`. All three already exist, narrowed to the
coach's own sessions, in `SessionsController#base_scope` and
`AttendanceController#accessible_sessions`. Building parallel endpoints would
duplicate the narrowing and give it a second place to be wrong. Only
`/coach/members` was genuinely missing.

Suite: backend **891 examples, 0 failures**; frontend **1217 passing**.

- **All-access contracts stopped crashing everything that read them.**
  Making `contracts.activity_id` nullable in Phase 3 created a contract with
  no activity without auditing the four places that read
  `contract.activity.name`: the contract serializer, the CSV export, the
  receipt PDF and the member's own app. All four would have raised
  `NoMethodError` on the first all-access membership sold. `Contract#activity_label`
  is now the single answer to "what is this for, in words", and
  `spec/requests/api/v1/all_access_contracts_spec.rb` walks a real one
  through each path — reverting the serializer fix makes two of them fail
  with the original error, which is the only reason to trust them.
- **A member can reach the second gym they belong to.** The member app read
  `gyms[0]` everywhere, so a person with two memberships could only see one.
  There is a switcher in the shell now, the choice is remembered, a stale
  remembered gym recovers instead of 404ing the app shut, and the schedule
  reloads when the active gym changes.

**`/me/contracts`, `/me/attendance` and `/me/companies` from `API_DESIGN.md`
§3 are not needed.** `GET /me/profile` already returns the subscription (with
`remaining_bookings`), the attendance rate and recent history, and the list
of gyms. Phase 1 recorded the member portal as missing all of this; it was
wrong. What was genuinely missing was the ability to *use* the gym list.

Suite: backend **900 examples, 0 failures**; frontend **1226 passing**.

- **The platform admin has a dashboard.** `GET /api/v1/admin/metrics` +
  `/admin/overview`, and the console lands there rather than on the companies
  table. Six numbers, each with a decision behind it; the one that matters
  most is `companies_with_activity` — how many gyms actually ran a session in
  30 days, the difference between a product being bought and being used.
  13 request specs, 9 component specs.

  Two numbers refuse to lie when they have nothing to say: the signup trend
  is null in a first month rather than reporting +100% against zero, and the
  in-use share is null with no gyms rather than dividing by zero.

  Writing `locked` as its own count exposed a gap — a company with no
  subscription row appeared in neither `open` nor `locked`. It is the
  remainder of `total - open` now, so the two always add up, matching how the
  company list already treats a missing subscription.

Suite: backend **913 examples, 0 failures**; frontend **1234 passing**.

### Remaining in Phase 6

- Coach: a week schedule view and a session-detail/roster screen (today's
  page covers the day; the week does not exist).
- Member portal: remaining sessions as the *headline* number rather than a
  muted line — a design change, so Phase 7.
- Owner dashboard: exceptions-first rather than a wall of statistics. The
  `attention` rows already exist in the dashboard payload; this is about what
  the page leads with, so it is largely Phase 7 too.

### A slip worth naming

Angular's `as` binding is only legal on a *primary* `@if`, never on an
`@else if`. I wrote `} @else if (x; as y) {` three times across the desk,
check-in and admin screens. The build catches it every time; the unit tests
do not, unless the component has a spec that compiles its template. Worth
remembering when writing a new screen's shell.

## Phase 7 — UI redesign 🔶 in progress

### Done — the foundation

**Bootstrap is gone.** `_fitora.scss` had already restyled `.btn`,
`.form-control`, `.table`, `.alert`, `.badge` and the tabs to the last rule,
so the app shipped a 420 kB stylesheet whose every visible declaration it
then overrode. What was genuinely still coming from the framework was a
bounded set of layout utilities plus five components nobody had themed —
which is why those five were the only places the old look still showed.

- `styles/_utilities.scss` — the utilities against Fitora's tokens, keeping
  Bootstrap's class names because 49 templates already say them. Spacing maps
  onto the token scale (`mb-3` is `--space-3`); sides are logical properties,
  so RTL comes free.
- `styles/_leftovers.scss` — input groups, spinner, progress, responsive
  table wrapper, colour input, checkbox row, tab list, compact table,
  warning button.
- **Stylesheet: 420.11 kB → 171.03 kB.**

**`scripts/check-css.mjs`** is what made that safe. Same shape as
`check-i18n.mjs`: every class a template asks for must have a rule behind it,
or the build fails. A missing rule is invisible until someone opens the
screen. It found **eight classes that had been styling nothing**:
`app-navbar-brand-text`, `app-navbar-menu`, `dashboard-setup-card`,
`fx-dashboard`, `fx-label`, `fx-session-tip-fill`, `is-video`,
`notif-detail`. Wired up as `npm run check:css`.

**`_fitora.scss` is decomposed** — thirteen partials grouped by concern, split
by a script against the file's own section markers, asserting every section
landed somewhere. Compiled output is byte-identical: this moved rules, it did
not change them.

The `UI_ARCHITECTURE.md` §1 target of "under 250 lines" is met in spirit
rather than literally: no single file is over 174 lines, and the global layer
is now findable. A single 250-line file was never the goal; being able to
open one component's rules was.

Frontend: **1234 passing**, lint clean, 919 classes all defined.

### Done — the screens

**Owner** — dashboard (exceptions first, five KPI cards to one footer line),
members (7 columns to 4), member profile (4 tabs to a banner and one
timeline), planning (coachless sessions visible where they get fixed),
catalogue (plans and activities composed onto one page), team (roles in
plain words), subscriptions/payments/bookings (shared header, duplicated
counts removed), settings (booking rules UI — the configuration engine had
none).

**Member** — remaining sessions is the page's headline, not its third muted
line.

**Coach** — the session under way, or the next one, above the day's list,
with the one action a coach takes. Session rows became real buttons.

**Admin** — overview added; companies, pricing, support and updates took the
shared header.

**One header across the product.** Twelve components were importing
`PageHeaderComponent` without rendering it by the end.

### Scaled back on purpose

- **Planning** stayed on FullCalendar. The maquette drew a hand-built grid;
  replacing it would cost month/day views, drag-to-move and timezone
  handling already fixed once. The two ideas worth having fit in its event
  renderer.
- **Catalogue** is composed, not merged — one component with two CRUD forms
  is the giant screen this work is undoing.
- **Settings** was not rebuilt. The maquette drew a tile hub; the real page
  is a rail that redirects to its first section, and a hub is worse for
  someone editing several sections in a row.
- **Payments, subscriptions and bookings keep tables.** A member became a
  row because a member is a person with a state; an amount, a method and a
  date are columns.

### What removing Bootstrap cost, and what caught it

Four regressions, every one found by the user looking at the screen rather
than by a check:

1. **Buttons unstyled** — the rules set `--bs-btn-*`, Bootstrap's variables,
   read by nothing once it left. Guard added: no `--bs-*` may remain.
2. **Fields borderless** — the rules set only what differed from Bootstrap's
   base (`border-color` with no `border`). No automated catch; needed eyes.
3. **The element reset went with it.** `<dl>`/`<dd>` margins spread a stats
   bar, heading margins pushed a count into a button, `<fieldset>` grew a
   border. Now `styles/_reset.scss`.
4. **A behaviour hook deleted as an unstyled class.** `.app-navbar-menu` is
   what `closest()` reads to tell a click inside the menu from one outside;
   without it every navbar dropdown shut in the same tick it opened. Guard
   added: a class the code reaches for must appear in a template.

The common thread: `check-css.mjs` proves a *name* exists, never that
anything *renders*. It says so in its own comments, and three bugs still
walked through that gap.

Frontend **1270 passing**, backend **935**, lint clean, 954 classes defined,
i18n complete in fr/en/ar.

### Remaining in Phase 7

Nothing blocking. The admin company-detail page (265 lines) is the largest
screen not revisited; it is internal-facing and works.

## Phases 8–10 — not started

See `MIGRATION_PLAN.md` §4.
