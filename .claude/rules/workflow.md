# Tower Data App Workflow

This workflow covers building data apps on Tower — dlt pipelines, dbt transformations, and Python scripts. It combines **review personas** (score, challenge, gate) with **execution skills** (build, configure, debug).

## Workflow Entry

```
User asks to build a data app
         │
         ▼
┌─────────────────────────────────────────────────┐
│ [OPTIONAL] gather-context                       │
│   Detects existing stack, conventions, resources│
│   Artifact: .tower/project-profile.md           │
│   Auto-runs if no profile exists on first skill │
│   Skipped for empty/new projects                │
└─────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────┐
│ [REVIEW] plan-business-analyst-review           │
│   Auto-detects intent:                          │
│   - High-intent → SCOPE CHECK (30s)             │
│   - Low-intent  → DISCOVERY (5min, scored)      │
│   Artifact: .tower/reviews/ba-review-{app}.md   │
│   Gate: Problem Clarity >= 6, Entity Cov >= 6   │
│         (SCOPE CHECK bypasses gate)             │
└─────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────┐
│ [REVIEW] plan-data-architect-review (PRE-LOAD)  │
│   Defines target schema before code exists      │
│   Artifact: .tower/reviews/architect-review-*   │
│   Gate: gate_result must be APPROVE             │
│   HARD GATE: hook blocks all file edits until   │
│   both BA + Architect reviews have APPROVE      │
└─────────────────────────────────────────────────┘
         │
         ▼
```

## Destination Decision

```
  Did user EXPLICITLY request
  a non-iceberg destination?
           │
       ┌───┴───┐
       │ NO    │ YES
       ▼       ▼
  Use tower-   Run `find-destination`
  managed      to identify the right
  iceberg      destination
  (DEFAULT)
       │       │
       ▼       ▼
  Continue to Build Phase
```

### Default: Tower-managed Iceberg
- Credentials auto-injected as `PYICEBERG_CATALOG__DEFAULT__*` env vars
- Available in `tower_run_local` — NOT Tower secrets, do NOT create via `tower_secrets_create`
- Must bridge env vars to dlt's naming convention in `task.py` + set `catalog_type = "rest"` in `.dlt/config.toml`
- See `create-rest-api-pipeline` step 6b for the exact bridging code

### Non-default: explicit destination
- Run `find-destination` to identify the right dlt destination
- Configure credentials via `setup-secrets`

## Build Phase

> **HARD GATE (hook-enforced):** All Edit and Write calls to project files are blocked
> until BA review AND Architect review both have `gate_result: APPROVE` in their
> artifacts. This is not guidance — a PreToolUse hook will deny the tool call.
> There is no bypass. Run `/plan-business-analyst-review` and
> `/plan-data-architect-review` before any code changes, including initial scaffolding.

```
[EXECUTE] init-tower-app
  Creates Tower app scaffold (task.py + Towerfile)
         │
         ▼
[EXECUTE] find-source
  Discovers the right dlt source for the user's data provider
  HOOK: Reads BA review artifact for scope context
         │
         ▼
[EXECUTE] create-rest-api-pipeline
  Scaffolds pipeline code, configures source and destination
  HOOK after: uv run python -c "import task" (syntax check)
  HOOK after: tower_file_validate (Towerfile still valid)
         │
         ▼
[EXECUTE] setup-secrets
  Configures Tower secrets (placeholder only — user fills real values in Tower UI)
  Only needed for SOURCE credentials (API keys, tokens)
  Iceberg destination credentials are handled automatically by Tower
         │
         ▼
[EXECUTE] debug-pipeline (tower_run_local)
  Run the pipeline, inspect traces and load packages, fix errors
  HOOK after success: dlt pipeline schema --format mermaid
  HOOK after success: dlt pipeline trace
```

## Running Pipelines

**CRITICAL: NEVER use `tower_run_remote`.** Always use `tower_run_local` for running pipelines during development AND debugging. The `tower_run_local` tool has access to Tower secrets and Tower-managed catalog credentials.

## Review Phase

```
[REVIEW] plan-data-engineer-review (DEV REVIEW)
  Reads: task.py, .dlt/config.toml, Towerfile, tower_apps_logs, trace
  Scores: incremental strategy, error resilience, resource efficiency, observability, test coverage
  Pass/fail: Tower integration, secrets, pagination, write disposition
  Review-only — does not modify code
  Artifact: .tower/reviews/engineer-review-{app}-dev.md
         │
         ▼
[REVIEW] data-analyst-explore (PROFILE)
  Absorbs validate-data — schema diagram, column profiling, spot checks
  Scores: completeness, freshness, consistency, queryability, discoverability
  Routes issues to responsible persona (null cols → Architect, row mismatch → Engineer)
  Artifact: .tower/reviews/analyst-profile-{app}.md
         │
         ▼
[REVIEW] plan-data-engineer-review (PROD READINESS)
  Absorbs adjust-endpoint — removes dev scaffolding, hardens for production
  HOOK at start: grep -rn "dev_mode|add_limit" task.py (must find nothing)
  Removes: dev_mode, .add_limit(), debug date filters, debug config settings
  Adds: explicit paginators, merge + primary_key, incremental loading
  HOOK after: uv run python -c "import task" + tower_file_validate
  Gate: all pass/fail checks pass; Incremental >= 5, Error Resilience >= 5
  Artifact: .tower/reviews/engineer-review-{app}-prod.md
```

## Deploy Phase

```
[REVIEW] plan-ops-review (PRE-DEPLOY)
  Schedule, cost, failure recovery, monitoring
  HOOK: tower_file_validate + tower_secrets_list (all required secrets exist)
  Gate: Failure Recovery >= 5, Schedule Appropriateness >= 5
         │
         ▼
[GATE] Review Readiness Dashboard
  Print summary of all review artifacts:
  | Review | Date | Gate | Stale? |
  |--------|------|------|--------|
  Compare artifact commit hash vs current HEAD; warn if >3 commits behind
         │
         ▼
[EXECUTE] tower_deploy → production
```

## Optional Reviews (on demand)

- `plan-data-architect-review` — when schema quality needs deeper review (PRE-LOAD or POST-LOAD mode)
- `plan-security-review` (AUDIT) — before first deploy or on credential incidents
- `plan-business-analyst-review` (EXPANSION) — before adding endpoints to an existing pipeline
- `plan-data-engineer-review` (INCIDENT) — when tower_apps_logs shows production failures
- `plan-data-engineer-review` (OPTIMIZATION) — when pipeline is working but slow or expensive

## Extend

- **Add endpoints** (`new-endpoint`) — add more resources to the source. Run `plan-business-analyst-review` (EXPANSION) first.
- **View data** (`view-data` or `data-analyst-explore` EXPLORE mode) — query and explore loaded data

## Handover to Other Toolkits

When the user's needs go beyond this toolkit:
- **data-exploration** — interactive notebooks, charts, dashboards, deeper analysis with marimo
