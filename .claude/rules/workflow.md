# Tower Data App Workflow

Intent-driven routing for Tower data apps. Hard rules are in tower-rules.md. This file maps (intent + project state) to the right skill.

## State Detection

Check these signals to determine where the project is. Skills also detect state in their Step 0.

| Signal | How to check | State |
|--------|-------------|-------|
| No `pyproject.toml` | `ls pyproject.toml` | **no-project** |
| No `Towerfile`, no `*.py` with runnable code | `ls Towerfile` + no Python scripts found | **no-app** |
| No `Towerfile`, but `*.py` files with runnable code exist | `find . -name "*.py" -not -path "./.venv/*" -not -path "./__pycache__/*" -not -name "setup.py" -not -name "conftest.py" -not -name "noxfile.py" \| head -5` | **has-code** |
| `Towerfile` exists | `ls Towerfile` | **has-app** |
| At least one successful `tower_run_local` | `tower_apps_logs` shows success | **ran-successfully** |
| `.tower/reviews/engineer-review-*-prod*` with APPROVE | glob + read frontmatter | **prod-ready** |
| `tower_deploy` completed, schedule configured | `tower_schedules_list` returns entries | **deployed** |

## Routing Table

Given the user's intent (see tower-rules.md intent scoring) and project state, suggest the next skill.

| Intent | State | Suggested skill | Why |
|--------|-------|-----------------|-----|
| **feature** | no-project / no-app | `init-tower-app` | Scaffold first |
| **feature** | has-code | `init-tower-app` (WRAP) | Wrap existing code into Tower app first |
| **feature** | has-app | `plan-business-analyst-review` | Scope before building |
| **feature** | has-app (dlt, new endpoint) | `plan-business-analyst-review` (EXPANSION) | Scope the addition |
| **feature** | has-app (dlt, first endpoint) | `find-source` → `create-rest-api-pipeline` | Build the dlt pipeline |
| **feature** | has-app (asgi/python) | Edit code directly | No dlt-specific scaffolding needed |
| **yolo** | has-code | `init-tower-app` (WRAP) → `debug-pipeline` | Wrap and run fast |
| **yolo** | has-app+ | Skip reviews, go to the execution skill that matches the need | Move fast |
| **hotfix** | has-code | `init-tower-app` (WRAP) → `debug-pipeline` | Need Tower runtime to debug |
| **hotfix** | has-app+ | `debug-pipeline` | Fix the bug |
| **hotfix** | deployed | `plan-data-engineer-review` (INCIDENT) | Diagnose production failure |
| **investigation** | ran-successfully+ | `data-analyst-explore` | Explore data |
| **investigation** | any | Read code, `tower_apps_logs`, no skill needed | Just look around |
| **refactor** | has-code | `init-tower-app` (WRAP) → reviews | Wrap first, then review |
| **refactor** | has-app+ | `plan-business-analyst-review` + `plan-data-architect-review` | Review scope + schema first |
| deploy request | has-code | `init-tower-app` (WRAP) → `debug-pipeline` | Must be Tower app to deploy |
| deploy request | has-app | `debug-pipeline` | Get it running first |
| deploy request | prod-ready | `plan-ops-review` → `tower_deploy` | Pre-deploy check |
| deploy request | ran-successfully | `plan-data-engineer-review` (PROD READINESS) | Harden first |
| vague / unclear | any | `gather-context` or ask the user | Clarify before acting |

When ambiguous between intents, say: "This looks like a [category] — let me run a quick review before we start." For feature/refactor, reviews are mandatory regardless of user response.

## Review Guidance

Reviews are **mandatory** for feature and refactor intents. For other intents (yolo, hotfix, investigation), reviews are optional but available on request. Each review adds value at specific moments.

| Review | Suggested when | Artifact |
|--------|---------------|----------|
| `plan-business-analyst-review` | Before building a new app or adding features/endpoints | `.tower/reviews/ba-review-{app}*.md` |
| `plan-data-architect-review` | Before first load (PRE-LOAD) or after data is loaded (POST-LOAD) | `.tower/reviews/architect-review-{app}*.md` |
| `plan-data-engineer-review` | After `debug-pipeline` succeeds (DEV), before deploy (PROD READINESS) | `.tower/reviews/engineer-review-{app}*.md` |
| `data-analyst-explore` | After data is loaded, to profile quality | `.tower/reviews/analyst-profile-{app}*.md` |
| `plan-ops-review` | Before `tower_deploy` | `.tower/reviews/ops-review-{app}*.md` |
| `plan-security-review` | Before first deploy or on credential incidents | `.tower/reviews/security-review-{app}*.md` |

## Review Modes (feature/refactor only)

How reviews run depends on scope clarity. See tower-rules.md for the scope classification table.

### Narrow Scope — Autonomous Subagent Review → Mini-Plan

**Signal:** User names a specific, well-defined feature (e.g., "add Discord alerts for new bug tickets", "add a new endpoint for pull requests", "switch destination to Snowflake").

**Process:**
1. Explore the codebase to understand current state
2. Draft a v1 mini-plan covering: what changes, where, why, and key technical decisions
3. Launch two subagents in parallel:
   - **BA subagent** — pass the v1 plan, invoke in AUTONOMOUS mode. Ask for: scope pass/fail, missing entities, backfill concerns, scope creep flags
   - **Architect subagent** — pass the v1 plan, invoke in AUTONOMOUS mode. Ask for: schema impact, query approach, dedup strategy, blocking issues
4. Read both reviews, incorporate feedback into a v2 mini-plan
5. Present v2 to the user via plan mode or direct presentation
6. User approves → proceed to implementation. User adjusts → revise and re-present.

**No review artifacts written.** The mini-plan IS the artifact. Reviews are folded in, not separate documents.

**No AskUserQuestion during review.** The BA and architect subagents review autonomously — they return structured feedback, not interactive questions. The user's first interaction is seeing the finished plan.

### Broad Scope — Interactive Review Session → Plan

**Signal:** User describes a goal without specific technical details (e.g., "I want analytics on pipeline health", "we need monitoring"), or the feature spans multiple components/endpoints.

**Process:**
1. Invoke `/plan-business-analyst-review` as a skill (DISCOVERY or EXPANSION mode) — interactive session with the user, full scoring, AskUserQuestion for each decision
2. On BA approval, invoke `/plan-data-architect-review` as a skill (PRE-LOAD mode) — interactive schema review
3. Review artifacts written to `.tower/reviews/`
4. Plan emerges as the combined output of both reviews

**Full artifacts written.** Both BA and architect write review documents to `.tower/reviews/`.

**User participates in scoping.** AskUserQuestion used throughout. The user helps shape the plan.

## Next-Step Suggestions

After each skill completes, suggest the next step based on outcome.

| Skill | On success | On blocked / needs context |
|-------|-----------|---------------------------|
| `gather-context` | Route via routing table above | Ask user to clarify |
| `init-tower-app` | SCAFFOLD: `find-source` (dlt) or BA review (feature intent) or edit code (asgi/python). WRAP: `debug-pipeline` (existing code is already the app) | Fix Tower login / uv setup |
| `plan-business-analyst-review` | dlt: `plan-data-architect-review` or `find-source` → `create-rest-api-pipeline`. asgi/python: proceed to implementation | User must clarify scope |
| `plan-data-architect-review` | dlt: `find-source` → `create-rest-api-pipeline` (PRE-LOAD) or `plan-data-engineer-review` (POST-LOAD). Other: `plan-data-engineer-review` | Fix schema issues first |
| `find-source` | `create-rest-api-pipeline` | Broaden search or ask user |
| `create-rest-api-pipeline` | `setup-secrets` → `debug-pipeline` | Fix scaffold errors |
| `setup-secrets` | `debug-pipeline` | User must fill secrets in Tower UI |
| `debug-pipeline` (dlt, load successful) | `data-analyst-explore` (always suggest) + `plan-data-engineer-review` (DEV) | Check `tower_apps_logs`, retry |
| `debug-pipeline` (asgi/python, success) | `plan-data-engineer-review` (DEV) or deploy | Check `tower_apps_logs`, retry |
| `data-analyst-explore` | `plan-data-engineer-review` (PROD READINESS) | Route issues to responsible persona |
| `plan-data-engineer-review` (DEV) | `data-analyst-explore` for profiling | Address findings |
| `plan-data-engineer-review` (PROD) | `plan-ops-review` | Fix failing checks |
| `plan-ops-review` | `tower_deploy` | Fix schedule / resources |
| `plan-security-review` | `plan-ops-review` | Fix credential issues |

**Data exploration suggestion (dlt apps):** When a dlt data pipeline runs successfully (load completes), `data-analyst-explore` MUST always be presented as a next-step option. It should not run automatically — the user chooses whether to explore. For feature/refactor intents, state it as the recommended next step. For yolo/hotfix/investigation intents, include it as the first option in the `AskUserQuestion` choices. This does not apply to ASGI apps or plain Python scripts.

## Next-Step Presentation

How next steps are presented depends on the user's intent:

| Intent | Presentation |
|--------|-------------|
| **feature** / **refactor** | Directive — state the recommended next skill and proceed (or ask if ambiguous using `AskUserQuestion`) |
| **yolo** / **investigation** / **hotfix** | Prompt — present 2-3 relevant options from the suggestions table using `AskUserQuestion` (never as plain text bullets) |

**IMPORTANT:** When presenting next-step options to the user, ALWAYS use the `AskUserQuestion` tool. Never list options as plain markdown bullets or numbered lists in text output. This applies to all skills at their completion step and to any routing decision where the user has a choice.

## Destination Decision (dlt apps only)

Default: **Tower-managed Iceberg** (credentials auto-injected, no Tower secrets needed).
- Set `catalog_type = "rest"` in `.dlt/config.toml`
- Bridge env vars in `task.py` (see `create-rest-api-pipeline` step 6b)

Non-default: Only if the user explicitly requests another destination.
- Run `find-destination` to identify the right dlt destination
- Configure credentials via `setup-secrets`

For **ASGI apps** and **plain Python scripts**, there is no destination decision — the app defines its own output (HTTP responses, files, database writes, stdout, etc.).

## Handover

When user needs go beyond this toolkit:
- **data-exploration** — interactive notebooks, charts, dashboards with marimo
